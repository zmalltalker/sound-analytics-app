//
//  RecordingWAVExportService.swift
//  Rich sound recorder
//
//  Created by Codex on 19/03/2026.
//

import AVFoundation
import Foundation

enum RecordingWAVExportError: LocalizedError {
    case missingSamples
    case missingSampleRate
    case invalidHexLength
    case invalidHexByte(String)
    case invalidAudioFormat
    case bufferCreationFailed

    var errorDescription: String? {
        switch self {
        case .missingSamples:
            return "This clip does not contain sample data."
        case .missingSampleRate:
            return "This clip does not include a sample rate."
        case .invalidHexLength:
            return "The sample payload has an invalid hex length."
        case .invalidHexByte(let value):
            return "Invalid hex byte: \(value)"
        case .invalidAudioFormat:
            return "Could not create an audio format for WAV export."
        case .bufferCreationFailed:
            return "Could not create an audio buffer for WAV export."
        }
    }
}

struct RecordingWAVExportService {
    func exportWAV(for clip: RecordingClip) throws -> URL {
        guard let samplesHex = clip.samplesHex else {
            throw RecordingWAVExportError.missingSamples
        }
        guard let sampleRate = clip.sampleRate else {
            throw RecordingWAVExportError.missingSampleRate
        }

        let samples = try normalize(samples: decodeHexDoubles(samplesHex))

        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false) else {
            throw RecordingWAVExportError.invalidAudioFormat
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            throw RecordingWAVExportError.bufferCreationFailed
        }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        let channelData = buffer.floatChannelData![0]
        for (index, value) in samples.enumerated() {
            channelData[index] = Float(value)
        }

        let docsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filename = "clip_\(clip.id).wav"
        let fileURL = docsDirectory.appendingPathComponent(filename)

        let file = try AVAudioFile(
            forWriting: fileURL,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        try file.write(from: buffer)

        return fileURL
    }

    private func decodeHexDoubles(_ hexString: String) throws -> [Double] {
        guard hexString.count.isMultiple(of: 16) else {
            throw RecordingWAVExportError.invalidHexLength
        }

        let byteData = try hexData(from: hexString)
        var samples: [Double] = []
        samples.reserveCapacity(byteData.count / 8)

        var offset = 0
        while offset + 8 <= byteData.count {
            let chunk = byteData[offset..<(offset + 8)]
            let bitPattern = chunk.enumerated().reduce(UInt64(0)) { partialResult, element in
                partialResult | (UInt64(element.element) << (element.offset * 8))
            }
            samples.append(Double(bitPattern: bitPattern))
            offset += 8
        }

        return samples
    }

    private func normalize(samples: [Double]) -> [Double] {
        guard let peak = samples.map({ abs($0) }).max(), peak > 0 else {
            return samples
        }

        let scale = min(1.0 / peak, 8.0)
        return samples.map { sample in
            let normalized = sample * scale
            return max(-1.0, min(1.0, normalized))
        }
    }

    private func hexData(from string: String) throws -> [UInt8] {
        guard string.count.isMultiple(of: 2) else {
            throw RecordingWAVExportError.invalidHexLength
        }

        var bytes: [UInt8] = []
        bytes.reserveCapacity(string.count / 2)

        var index = string.startIndex
        while index < string.endIndex {
            let nextIndex = string.index(index, offsetBy: 2)
            let byteString = String(string[index..<nextIndex])
            guard let byte = UInt8(byteString, radix: 16) else {
                throw RecordingWAVExportError.invalidHexByte(byteString)
            }
            bytes.append(byte)
            index = nextIndex
        }

        return bytes
    }
}
