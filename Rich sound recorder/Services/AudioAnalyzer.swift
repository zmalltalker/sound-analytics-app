import AVFoundation
import Accelerate

// MARK: - Detection configuration

/// All tuning knobs for the offline event detector.
///
/// Quick reference for common material:
///   - Drum hits / sharp transients: thresholdMultiplier 5–8, minEventDuration 0.010, mergeGapDuration 0.040
///   - Hand claps / finger snaps:    thresholdMultiplier 3–5, minEventDuration 0.015, mergeGapDuration 0.060
///   - Speech / soft sounds:         thresholdMultiplier 2–3, minEventDuration 0.050, mergeGapDuration 0.150
///   - Noisy environment:            raise noiseFloorPercentile toward 0.35–0.45
struct EventDetectionConfig {

    /// Duration of each RMS analysis window (seconds).
    /// Shorter → finer time resolution; longer → smoother energy curve.
    /// 10–30 ms works well for percussive hits; 50–100 ms for sustained tones.
    var windowDuration: TimeInterval = 0.020        // 20 ms

    /// Stride between successive windows (seconds).  Overlap = window − hop.
    /// 50% overlap (hop = window / 2) balances resolution and compute cost.
    var hopDuration: TimeInterval = 0.010           // 10 ms (50% overlap)

    /// How many times above the noise floor an RMS value must be to trigger.
    /// Raise in noisy recordings; lower for very quiet source material.
    var thresholdMultiplier: Float = 4.0

    /// Events shorter than this are discarded as artefacts (seconds).
    var minEventDuration: TimeInterval = 0.020      // 20 ms

    /// Gaps smaller than this between two active regions are bridged into one event (seconds).
    /// Raise if a single hit is split into multiple events by the detector.
    var mergeGapDuration: TimeInterval = 0.080      // 80 ms

    /// After an event ends, suppress new triggers for this long (seconds).
    /// Prevents retriggering on reverb tail or cymbal wash.
    var refractoryDuration: TimeInterval = 0.050    // 50 ms

    /// Percentile of all RMS windows used to estimate the noise floor (0.0–1.0).
    /// 0.20 = 20th percentile — works when the majority of the file is silence.
    var noiseFloorPercentile: Float = 0.20

    /// Maximum number of waveform display points to generate.  Higher = more detail, more memory.
    var maxWaveformPoints: Int = 2000
}

// MARK: - Errors

enum AudioAnalyzerError: LocalizedError {
    case bufferAllocationFailed
    case noAudioData

    var errorDescription: String? {
        switch self {
        case .bufferAllocationFailed: return "Failed to allocate audio processing buffer"
        case .noAudioData:            return "Audio file contains no readable sample frames"
        }
    }
}

// MARK: - Analyzer

/// Offline audio analysis service.  Reads the file in ~1-second chunks so memory usage
/// stays bounded regardless of recording length, then computes waveform display data and
/// detects sound events using RMS energy thresholding.
///
/// Usage:
///   let result = try await AudioAnalyzer().analyze(url: fileURL)
///
/// The method is isolated to the actor's own background executor, so the main thread
/// remains responsive during analysis of large files.
actor AudioAnalyzer {

    func analyze(url: URL, config: EventDetectionConfig = EventDetectionConfig()) async throws -> AudioAnalysisResult {

        let audioFile    = try AVAudioFile(forReading: url)
        let format       = audioFile.processingFormat   // always Float32, non-interleaved
        let sampleRate   = format.sampleRate
        let channelCount = Int(format.channelCount)
        let totalFrames  = Int(audioFile.length)
        let duration     = Double(totalFrames) / sampleRate

        // ── Analysis window sizing ─────────────────────────────────────────────
        let windowSamples = max(1, Int(sampleRate * config.windowDuration))
        let hopSamples    = max(1, Int(sampleRate * config.hopDuration))

        // One waveform display point per stride samples
        let waveformStride = max(1, totalFrames / config.maxWaveformPoints)

        // Read in chunks of ~1 s (at least 8× window size for good carry-over throughput)
        let chunkCapacity = AVAudioFrameCount(max(Int(sampleRate), windowSamples * 8))
        guard let readBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkCapacity) else {
            throw AudioAnalyzerError.bufferAllocationFailed
        }

        // ── Accumulation state ─────────────────────────────────────────────────
        var rmsFrames:     [(time: TimeInterval, value: Float)] = []
        var waveformPoints: [WaveformPoint] = []

        // Samples from the previous chunk that haven't filled a complete hop window yet.
        // carryStartGlobal is the file-level sample index of carry[0].
        var carry:             [Float] = []
        var carryStartGlobal = 0

        // Waveform stride-window accumulator
        var wfPeak:             Float = 0
        var wfRMSSum:           Float = 0
        var wfCount                   = 0
        var wfWindowStartGlobal       = 0  // global index of the current wf window's first sample

        // ── Read loop ──────────────────────────────────────────────────────────
        while audioFile.framePosition < audioFile.length {
            try audioFile.read(into: readBuffer)
            guard readBuffer.frameLength > 0 else { break }
            guard let channelData = readBuffer.floatChannelData else { break }

            let frameLength = Int(readBuffer.frameLength)

            // Mix to mono (copy ch 0, then accumulate remaining channels)
            var mono = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
            if channelCount > 1 {
                for ch in 1..<channelCount {
                    vDSP_vadd(mono, 1, channelData[ch], 1, &mono, 1, vDSP_Length(frameLength))
                }
                var invN = 1.0 / Float(channelCount)
                vDSP_vsmul(mono, 1, &invN, &mono, 1, vDSP_Length(frameLength))
            }

            // ── RMS hop-window analysis ────────────────────────────────────────
            // Prepend leftover samples so windows span chunk boundaries correctly.
            let combined = carry + mono
            var offset   = 0

            combined.withUnsafeBufferPointer { buf in
                while offset + windowSamples <= combined.count {
                    var rms: Float = 0
                    vDSP_rmsqv(buf.baseAddress! + offset, 1, &rms, vDSP_Length(windowSamples))
                    if rms.isNaN { rms = 0 }

                    let centerGlobal = carryStartGlobal + offset + windowSamples / 2
                    rmsFrames.append((time: Double(centerGlobal) / sampleRate, value: rms))
                    offset += hopSamples
                }
            }

            // Unconsumed samples become the next chunk's carry-over
            carry             = Array(combined[offset...])
            carryStartGlobal += offset

            // ── Waveform accumulation (stride-based, no carry needed) ──────────
            for sample in mono {
                let absVal = abs(sample)
                wfPeak    = max(wfPeak, absVal)
                wfRMSSum += sample * sample
                wfCount  += 1

                if wfCount >= waveformStride {
                    let centerGlobal = wfWindowStartGlobal + wfCount / 2
                    let rms          = sqrt(max(0, wfRMSSum / Float(wfCount)))
                    waveformPoints.append(WaveformPoint(
                        time:      Double(centerGlobal) / sampleRate,
                        amplitude: wfPeak,
                        rms:       rms
                    ))
                    wfWindowStartGlobal += wfCount
                    wfPeak   = 0
                    wfRMSSum = 0
                    wfCount  = 0
                }
            }
        }

        // Flush the partial waveform window at end-of-file
        if wfCount > 0 {
            let centerGlobal = wfWindowStartGlobal + wfCount / 2
            let rms          = sqrt(max(0, wfRMSSum / Float(wfCount)))
            waveformPoints.append(WaveformPoint(
                time:      Double(centerGlobal) / sampleRate,
                amplitude: wfPeak,
                rms:       rms
            ))
        }

        guard !rmsFrames.isEmpty else { throw AudioAnalyzerError.noAudioData }

        // Normalise waveform amplitudes to 0–1 relative to the loudest peak
        let maxAmp = waveformPoints.map(\.amplitude).max() ?? 1
        if maxAmp > 0 {
            let scale = 1.0 / maxAmp
            waveformPoints = waveformPoints.map {
                WaveformPoint(time: $0.time, amplitude: $0.amplitude * scale, rms: $0.rms * scale)
            }
        }

        // ── Noise floor & threshold ────────────────────────────────────────────
        let rmsValues  = rmsFrames.map(\.value)
        let sorted     = rmsValues.sorted()
        let noiseIdx   = max(0, Int(Float(sorted.count) * config.noiseFloorPercentile))
        let noiseFloor = sorted[noiseIdx]
        // Keep threshold above zero even for completely silent files
        let threshold  = max(noiseFloor * config.thresholdMultiplier, 1e-6)

        // ── Build raw active-window runs ───────────────────────────────────────
        struct RawEvent {
            var start, end, peakTime: TimeInterval
            var peakRMS: Float
        }

        var rawEvents: [RawEvent] = []
        var inEvent              = false
        var cur                  = RawEvent(start: 0, end: 0, peakTime: 0, peakRMS: 0)

        for i in rmsValues.indices {
            let t   = rmsFrames[i].time
            let rms = rmsValues[i]

            if rms > threshold {
                if !inEvent {
                    inEvent = true
                    cur = RawEvent(
                        start:    t - config.windowDuration / 2,
                        end:      t + config.windowDuration / 2,
                        peakTime: t,
                        peakRMS:  rms
                    )
                } else {
                    cur.end = t + config.windowDuration / 2
                    if rms > cur.peakRMS { cur.peakRMS = rms; cur.peakTime = t }
                }
            } else if inEvent {
                inEvent = false
                rawEvents.append(cur)
            }
        }
        if inEvent { rawEvents.append(cur) }

        // ── Merge events separated by a gap < mergeGapDuration ────────────────
        var merged: [RawEvent] = []
        for e in rawEvents {
            if var last = merged.last, e.start - last.end < config.mergeGapDuration {
                merged.removeLast()
                last.end = e.end
                if e.peakRMS > last.peakRMS { last.peakRMS = e.peakRMS; last.peakTime = e.peakTime }
                merged.append(last)
            } else {
                merged.append(e)
            }
        }

        // ── Filter by minimum duration and refractory period ──────────────────
        var events:       [AudioEventRegion] = []
        var lastEventEnd: TimeInterval       = -.infinity

        for e in merged {
            guard e.end - e.start >= config.minEventDuration else { continue }
            guard e.start >= lastEventEnd + config.refractoryDuration else { continue }
            lastEventEnd = e.end

            // Score: how far above the noise floor the peak is, normalised so threshold = 1.0
            let scoreDenom = max(threshold - noiseFloor, 1e-9)
            let score      = min(1.0, max(0, (e.peakRMS - noiseFloor) / scoreDenom))

            events.append(AudioEventRegion(
                id:            UUID(),
                startTime:     max(0, e.start),
                endTime:       min(duration, e.end),
                peakTime:      e.peakTime,
                peakAmplitude: e.peakRMS,
                score:         score
            ))
        }

        return AudioAnalysisResult(
            url:          url,
            duration:     duration,
            sampleRate:   sampleRate,
            channelCount: channelCount,
            waveform:     waveformPoints,
            events:       events,
            noiseFloor:   noiseFloor
        )
    }
}
