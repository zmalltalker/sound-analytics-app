import AVFoundation

// MARK: - Microphone Mode

/// Maps to the same three modes exposed in iOS Control Center for apps using the mic.
enum MicMode: String, CaseIterable, Identifiable {
    case wideSpectrum  = "Wide Spectrum"
    case standard      = "Standard"
    case voiceIsolation = "Voice Isolation"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .wideSpectrum:
            return "Raw capture — no noise reduction or processing. Best for ML analysis."
        case .standard:
            return "Default iOS processing — balanced for general use."
        case .voiceIsolation:
            return "Focuses on voice, suppresses background noise."
        }
    }

    /// AVAudioSession mode that most closely matches the Control Center selection.
    var sessionMode: AVAudioSession.Mode {
        switch self {
        case .wideSpectrum:   return .measurement  // disables AGC, noise reduction, EQ
        case .standard:       return .default
        case .voiceIsolation: return .voiceChat    // adds echo cancellation + voice focus
        }
    }

    var iconName: String {
        switch self {
        case .wideSpectrum:    return "waveform"
        case .standard:        return "mic"
        case .voiceIsolation:  return "mic.badge.plus"
        }
    }
}

// MARK: - Sample Rate

enum RecordSampleRate: Double, CaseIterable, Identifiable {
    case hz8000  =  8_000
    case hz16000 = 16_000
    case hz22050 = 22_050
    case hz44100 = 44_100
    case hz48000 = 48_000
    case hz96000 = 96_000

    var id: Double { rawValue }

    var label: String {
        let khz = rawValue / 1_000
        return khz == khz.rounded() ? "\(Int(khz)) kHz" : "\(khz) kHz"
    }

    var detail: String {
        switch self {
        case .hz8000:  return "Telephone"
        case .hz16000: return "Voice / speech"
        case .hz22050: return "FM radio"
        case .hz44100: return "CD quality"
        case .hz48000: return "Studio / broadcast"
        case .hz96000: return "High-resolution"
        }
    }

    /// Highest frequency that can be reproduced at this rate.
    var nyquist: Double { rawValue / 2 }
}

// MARK: - Channels

enum RecordChannels: Int, CaseIterable, Identifiable {
    case mono   = 1
    case stereo = 2

    var id: Int { rawValue }
    var label: String { self == .mono ? "Mono" : "Stereo" }
}

// MARK: - Encoding

enum RecordEncoding: String, CaseIterable, Identifiable {
    case pcm  = "PCM"
    case aac  = "AAC"
    case alac = "ALAC"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .pcm:  return "Uncompressed WAV — lossless, best for analysis"
        case .aac:  return "Lossy compressed M4A — small files"
        case .alac: return "Lossless compressed M4A"
        }
    }

    var formatID: AudioFormatID {
        switch self {
        case .pcm:  return kAudioFormatLinearPCM
        case .aac:  return kAudioFormatMPEG4AAC
        case .alac: return kAudioFormatAppleLossless
        }
    }

    var fileExtension: String { self == .pcm ? "wav" : "m4a" }
}

// MARK: - Aggregate Settings

struct AudioSettings {
    var micMode:    MicMode           = .wideSpectrum
    var sampleRate: RecordSampleRate  = .hz48000
    var channels:   RecordChannels    = .mono
    var encoding:   RecordEncoding    = .pcm

    /// AVAudioFile settings dict. Sample rate may be overridden by actual hardware rate.
    func fileSettings(actualSampleRate: Double? = nil) -> [String: Any] {
        var s: [String: Any] = [
            AVFormatIDKey:             encoding.formatID,
            AVSampleRateKey:           actualSampleRate ?? sampleRate.rawValue,
            AVNumberOfChannelsKey:     channels.rawValue,
        ]
        if encoding == .pcm {
            s[AVLinearPCMBitDepthKey]    = 24
            s[AVLinearPCMIsFloatKey]     = false
            s[AVLinearPCMIsBigEndianKey] = false
        }
        return s
    }
}
