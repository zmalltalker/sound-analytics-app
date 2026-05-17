import Foundation

// MARK: - Waveform display data

/// One amplitude sample for waveform rendering, representing a short window of audio.
struct WaveformPoint {
    /// Center time (seconds from file start) of the display window.
    let time: TimeInterval
    /// Normalized peak absolute amplitude in 0–1 (1 = loudest frame in the recording).
    let amplitude: Float
    /// Normalized RMS energy in 0–1 for the same window.
    let rms: Float
}

// MARK: - Detected event region

/// A contiguous region of audio activity that rose above the noise-floor threshold.
struct AudioEventRegion: Identifiable {
    let id: UUID
    /// Time (seconds) when energy first crosses the threshold.
    let startTime: TimeInterval
    /// Time (seconds) when energy returns below the threshold.
    let endTime: TimeInterval
    /// Time of the highest-energy hop window within this region.
    let peakTime: TimeInterval
    /// Raw RMS value at the peak window (compare with AudioAnalysisResult.noiseFloor).
    let peakAmplitude: Float
    /// Confidence proxy 0–1: how far above the noise floor the peak sits (1 = at or above detection threshold).
    let score: Float

    var duration: TimeInterval { endTime - startTime }
}

// MARK: - Full analysis result

/// Complete offline analysis of one audio file.  Produced asynchronously by AudioAnalyzer.analyze(url:config:).
struct AudioAnalysisResult {
    let url: URL
    /// Total file duration in seconds.
    let duration: TimeInterval
    let sampleRate: Double
    let channelCount: Int

    /// Downsampled waveform data for display (≤ EventDetectionConfig.maxWaveformPoints entries).
    let waveform: [WaveformPoint]

    /// Detected sound-event regions, sorted by startTime.
    let events: [AudioEventRegion]

    /// Estimated background noise-floor RMS used as the detection baseline.
    let noiseFloor: Float

    // MARK: - Extension point: Spectrogram
    //
    // To add a per-hop spectrogram, add:
    //   let spectrogramFrames: [[Float]]?   // nil until spectrogram is enabled
    //
    // Each inner array is the magnitude output of a 2048-point vDSP FFT (size 1024, linear Hz bins).
    // Populate in AudioAnalyzer using vDSP_fft_zrip on each hop window, following the same
    // pattern already used in AudioRecorder.analyzeBuffer(_:sampleRate:).
    // Render with Canvas by mapping bin index → hue (e.g. dB → colour via a heat-map gradient).
}
