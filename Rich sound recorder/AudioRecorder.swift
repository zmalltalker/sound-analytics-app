import AVFoundation
import Accelerate
import Combine

/// Drives audio recording via AVAudioEngine and produces real-time FFT data for the UI.
@MainActor
final class AudioRecorder: ObservableObject {

    // MARK: - Published state

    @Published var isRecording      = false
    @Published var permissionDenied = false
    @Published var frequencyBands: [Float] = .init(repeating: 0, count: 32)
    @Published var inputLevel: Float = 0
    @Published var lastRecordingURL: URL?
    @Published var errorMessage: String?

    // MARK: - Private

    private var engine:     AVAudioEngine?
    private var outputFile: AVAudioFile?

    // MARK: - Permission

    func requestPermission() async {
        let granted = await AVAudioApplication.requestRecordPermission()
        permissionDenied = !granted
    }

    func refreshPermission() {
        permissionDenied = AVAudioApplication.shared.recordPermission == .denied
    }

    // MARK: - Recording lifecycle

    func start(settings: AudioSettings) {
        guard !isRecording else { return }
        errorMessage = nil

        do {
            print("🎬 Starting recording with settings: \(settings)")

            // Configure the audio session with the chosen mic mode.
            let session = AVAudioSession.sharedInstance()
            print("📱 Setting category...")
            try session.setCategory(.record, mode: settings.micMode.sessionMode, options: [])
            print("🎚️ Setting sample rate to \(settings.sampleRate.rawValue)...")
            try session.setPreferredSampleRate(settings.sampleRate.rawValue)
            // Note: We don't set preferred input channels - iOS hardware determines this
            // The actual channel count will be read from the input format
            print("✅ Activating session...")
            try session.setActive(true)

            let newEngine  = AVAudioEngine()
            let inputNode  = newEngine.inputNode
            let inputFmt   = inputNode.outputFormat(forBus: 0)

            print("🎵 Input format: \(inputFmt)")

            let docs    = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let name    = "rec_\(Int(Date().timeIntervalSince1970)).\(settings.encoding.fileExtension)"
            let fileURL = docs.appendingPathComponent(name)

            print("📁 File URL: \(fileURL)")

            // For PCM, write in the same format as the input to avoid conversion errors
            print("📝 Creating audio file for encoding: \(settings.encoding.rawValue)")
            if settings.encoding == .pcm {
                print("   Using input format settings: \(inputFmt.settings)")
                outputFile = try AVAudioFile(forWriting: fileURL, settings: inputFmt.settings)
            } else {
                // For compressed formats (AAC/ALAC), use custom settings
                let fileSettings = settings.fileSettings(actualSampleRate: inputFmt.sampleRate)
                print("   Using custom settings: \(fileSettings)")
                outputFile = try AVAudioFile(forWriting: fileURL, settings: fileSettings)
            }
            print("✅ Audio file created successfully")
            lastRecordingURL = fileURL

            // Capture what we need from the main-actor context before entering the tap closure.
            let capturedSampleRate = inputFmt.sampleRate

            print("🔌 Installing tap...")
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFmt) { [weak self] buffer, _ in
                // This closure runs on AVAudioEngine's internal thread.
                try? self?.outputFile?.write(from: buffer)

                let (bands, level) = AudioRecorder.analyzeBuffer(buffer, sampleRate: capturedSampleRate)

                DispatchQueue.main.async { [weak self] in
                    self?.frequencyBands = bands
                    self?.inputLevel     = level
                }
            }
            print("✅ Tap installed")

            print("▶️ Starting engine...")
            try newEngine.start()
            print("✅ Engine started")

            engine      = newEngine
            isRecording = true

            print("🎉 Recording started successfully!")

        } catch {
            print("❌ ERROR: \(error)")
            print("❌ Error code: \((error as NSError).code)")
            print("❌ Error domain: \((error as NSError).domain)")
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine     = nil
        outputFile = nil

        isRecording    = false
        frequencyBands = .init(repeating: 0, count: 32)
        inputLevel     = 0

        try? AVAudioSession.sharedInstance().setActive(false)
    }

    // MARK: - Real-time FFT

    /// Pure function — safe to call from any thread.
    nonisolated static func analyzeBuffer(_ buffer: AVAudioPCMBuffer,
                                          sampleRate: Double) -> ([Float], Float) {
        let bandCount = 32
        let empty: ([Float], Float) = (.init(repeating: 0, count: bandCount), 0)

        guard let channelData = buffer.floatChannelData?[0] else { return empty }
        let frameCount = Int(buffer.frameLength)
        guard frameCount >= 2 else { return empty }

        // ── FFT parameters ──────────────────────────────────────────────
        let fftN  = 1024
        let halfN = fftN / 2
        let log2n = vDSP_Length(log2(Double(fftN)))

        // Copy samples into a fixed-size buffer (zero-pad if shorter).
        var samples = [Float](repeating: 0, count: fftN)
        let copyCount = min(frameCount, fftN)
        for i in 0..<copyCount { samples[i] = channelData[i] }

        // Apply a Hann window to reduce spectral leakage.
        var window = [Float](repeating: 0, count: fftN)
        vDSP_hann_window(&window, vDSP_Length(fftN), Int32(vDSP_HANN_NORM))
        vDSP_vmul(samples, 1, window, 1, &samples, 1, vDSP_Length(fftN))

        // Pack real samples into the split-complex layout required by vDSP_fft_zrip:
        // even-indexed samples → real part, odd-indexed → imaginary part.
        var realParts = [Float](repeating: 0, count: halfN)
        var imagParts = [Float](repeating: 0, count: halfN)
        for i in 0..<halfN {
            realParts[i] = samples[i * 2]
            imagParts[i] = samples[i * 2 + 1]
        }

        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return empty }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        // Perform in-place real FFT and compute magnitudes.
        var mags = [Float](repeating: 0, count: halfN)
        realParts.withUnsafeMutableBufferPointer { realBuf in
            imagParts.withUnsafeMutableBufferPointer { imagBuf in
                var sc = DSPSplitComplex(realp: realBuf.baseAddress!,
                                        imagp: imagBuf.baseAddress!)
                vDSP_fft_zrip(fftSetup, &sc, 1, log2n, FFTDirection(FFT_FORWARD))
                mags.withUnsafeMutableBufferPointer { magBuf in
                    vDSP_zvabs(&sc, 1, magBuf.baseAddress!, 1, vDSP_Length(halfN))
                }
            }
        }

        // Normalise magnitudes.
        let scale = Float(1.0 / Float(fftN))
        var normalizedMags = [Float](repeating: 0, count: halfN)
        vDSP_vsmul(&mags, 1, [scale], &normalizedMags, 1, vDSP_Length(halfN))

        // ── Logarithmic band mapping (20 Hz → Nyquist) ──────────────────
        let minFreq: Float = 20
        let maxFreq  = Float(sampleRate / 2)
        let logMin   = log10(minFreq)
        let logMax   = log10(maxFreq)

        let bands: [Float] = (0..<bandCount).map { band in
            let t0 = Float(band)     / Float(bandCount)
            let t1 = Float(band + 1) / Float(bandCount)
            let freqLow  = pow(10, logMin + t0 * (logMax - logMin))
            let freqHigh = pow(10, logMin + t1 * (logMax - logMin))

            let binLow  = max(1, Int(freqLow  / Float(sampleRate) * Float(fftN)))
            let binHigh = max(binLow + 1, min(Int(freqHigh / Float(sampleRate) * Float(fftN)) + 1, halfN))

            let peak = normalizedMags[binLow..<binHigh].max() ?? 0
            // Map −80 dB … 0 dB to 0 … 1.
            let db = 20 * log10(max(peak, 1e-7))
            return max(0, min(1, (db + 80) / 80))
        }

        // ── RMS input level ──────────────────────────────────────────────
        var rms: Float = 0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameCount))

        return (bands, min(1, rms * 20))
    }
}
