//
//  MainView.swift
//  Rich sound recorder
//
//  Created by Marius Mathiesen on 17/03/2026.
//

import AVFoundation
import CoreML
import SoundAnalysis
import SwiftUI
import zlib

struct DetectionModelDescriptor: Identifiable, Hashable {
    let id: String
    let displayName: String
    let summary: String
    let bundledModelName: String?
    let downloadedArchiveURL: URL?
    let labelNames: [String]
}

struct DetectionEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let startTime: Double
    let endTime: Double
    let confidence: Double

    var timeRange: String {
        "\(Self.formatTime(startTime)) - \(Self.formatTime(endTime))"
    }

    private static func formatTime(_ value: Double) -> String {
        let totalSeconds = max(0, Int(value.rounded(.down)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

protocol DetectionModelProviding {
    func availableModels() async throws -> [DetectionModelDescriptor]
}

protocol EventDetectionServicing {
    func recognizeEvents(
        in recording: CompletedRecording,
        model: DetectionModelDescriptor
    ) async throws -> [DetectionEvent]
}

struct MockDetectionModelProvider: DetectionModelProviding {
    func availableModels() async throws -> [DetectionModelDescriptor] {
        [
            DetectionModelDescriptor(
                id: "baseline-acoustic-v1",
                displayName: "Baseline Acoustic v1",
                summary: "Fast general-purpose detector",
                bundledModelName: nil,
                downloadedArchiveURL: nil,
                labelNames: []
            ),
            DetectionModelDescriptor(
                id: "urban-events-v2",
                displayName: "Urban Events v2",
                summary: "Placeholder traffic and city event model",
                bundledModelName: nil,
                downloadedArchiveURL: nil,
                labelNames: []
            ),
            DetectionModelDescriptor(
                id: "industrial-watch-v1",
                displayName: "Industrial Watch v1",
                summary: "Placeholder machine anomaly model",
                bundledModelName: nil,
                downloadedArchiveURL: nil,
                labelNames: []
            )
        ]
    }
}

struct MockEventDetectionService: EventDetectionServicing {
    func recognizeEvents(
        in recording: CompletedRecording,
        model: DetectionModelDescriptor
    ) async throws -> [DetectionEvent] {
        try await Task.sleep(for: .milliseconds(700))

        let clipName = recording.fileURL.deletingPathExtension().lastPathComponent
        let duration = max(recording.audioEndTimestamp, 3)
        let earlyEnd = min(max(duration * 0.22, 1.2), max(duration - 0.8, 1.4))
        let middleStart = min(max(duration * 0.34, 1.4), max(duration - 1.2, 1.6))
        let middleEnd = min(max(duration * 0.63, middleStart + 0.8), max(duration - 0.4, middleStart + 0.9))
        let lateStart = min(max(duration * 0.74, middleEnd + 0.15), max(duration - 1.0, middleEnd + 0.2))
        let lateEnd = min(duration, max(duration * 0.94, lateStart + 0.5))

        return [
            DetectionEvent(
                id: "\(model.id)-1",
                title: "Transient event in \(clipName)",
                startTime: 0.15,
                endTime: earlyEnd,
                confidence: 0.94
            ),
            DetectionEvent(
                id: "\(model.id)-2",
                title: "Sustained pattern",
                startTime: middleStart,
                endTime: middleEnd,
                confidence: 0.81
            ),
            DetectionEvent(
                id: "\(model.id)-3",
                title: "Background activity",
                startTime: lateStart,
                endTime: lateEnd,
                confidence: 0.67
            )
        ]
    }
}

enum LocalSoundDetectionError: LocalizedError {
    case missingBundledModel
    case unsupportedModelSelection
    case noResultsProduced
    case invalidDownloadedModel
    case invalidModelOutput
    case zipArchiveUnsupported
    case modelCompilationFailed
    case audioConversionFailed

    var errorDescription: String? {
        switch self {
        case .missingBundledModel:
            return "The bundled sound classifier could not be found in the app bundle."
        case .unsupportedModelSelection:
            return "The selected model is not backed by a bundled classifier."
        case .noResultsProduced:
            return "The classifier did not return any sound events for this recording."
        case .invalidDownloadedModel:
            return "The downloaded model is missing the waveform input or probability output required for inference."
        case .invalidModelOutput:
            return "The model returned an output tensor that could not be interpreted."
        case .zipArchiveUnsupported:
            return "The downloaded model archive uses an unsupported ZIP layout."
        case .modelCompilationFailed:
            return "The downloaded model could not be compiled for local inference."
        case .audioConversionFailed:
            return "The recording could not be converted into the waveform format required by the model."
        }
    }
}

struct BundledDetectionModelProvider: DetectionModelProviding {
    func availableModels() async throws -> [DetectionModelDescriptor] {
        let bundledModels = [
            DetectionModelDescriptor(
                id: "demo-sound-classifier-1",
                displayName: "Demo sound classifier 1",
                summary: "Create ML classifier trained on DATASEC with 22 environmental sound classes",
                bundledModelName: "Demo sound classifier 1",
                downloadedArchiveURL: nil,
                labelNames: []
            ),
            DetectionModelDescriptor(
                id: "my-sound-classifier-1",
                displayName: "MySoundClassifier 1",
                summary: "Bundled Create ML drone-focused sound classifier",
                bundledModelName: "MySoundClassifier 1",
                downloadedArchiveURL: nil,
                labelNames: []
            )
        ].filter { model in
            guard let bundledModelName = model.bundledModelName else { return false }
            return Bundle.main.url(forResource: bundledModelName, withExtension: "mlmodelc") != nil
        }

        let downloadedModels = DownloadedDetectionModelProvider().availableDownloadedModels()
        let allModels = bundledModels + downloadedModels

        return allModels.isEmpty ? try await MockDetectionModelProvider().availableModels() : allModels
    }
}

struct DownloadedDetectionModelProvider {
    private struct DownloadedModelMetadata: Codable {
        let displayName: String
        let labelNames: [String]
        let modelVersion: String
        let projectUID: String
    }

    func availableDownloadedModels() -> [DetectionModelDescriptor] {
        guard let docsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let fileURLs = try? FileManager.default.contentsOfDirectory(
                at: docsDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        return fileURLs
            .filter { $0.pathExtension.lowercased() == "zip" && $0.lastPathComponent.hasPrefix("model_") }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .map { archiveURL in
                let metadataURL = archiveURL.appendingPathExtension("metadata.json")
                let metadata = loadMetadata(from: metadataURL)
                let displayName = metadata?.displayName ?? fallbackDisplayName(for: archiveURL, metadata: metadata)
                let labels = metadata?.labelNames ?? []
                let summary: String

                if labels.isEmpty {
                    summary = "Downloaded project model"
                } else {
                    summary = "Downloaded project model with \(labels.count) labels"
                }

                return DetectionModelDescriptor(
                    id: archiveURL.lastPathComponent,
                    displayName: displayName,
                    summary: summary,
                    bundledModelName: nil,
                    downloadedArchiveURL: archiveURL,
                    labelNames: labels
                )
            }
    }

    private func loadMetadata(from metadataURL: URL) -> DownloadedModelMetadata? {
        guard let data = try? Data(contentsOf: metadataURL) else { return nil }
        return try? JSONDecoder().decode(DownloadedModelMetadata.self, from: data)
    }

    private func fallbackDisplayName(for archiveURL: URL, metadata: DownloadedModelMetadata?) -> String {
        if let metadata {
            return "\(metadata.displayName) v\(metadata.modelVersion)"
        }

        let stem = archiveURL.deletingPathExtension().lastPathComponent
        let prefix = "model_"

        guard stem.hasPrefix(prefix) else {
            return stem
        }

        let rawValue = String(stem.dropFirst(prefix.count))
        guard let separatorIndex = rawValue.lastIndex(of: "_") else {
            return stem
        }

        let projectIdentifier = String(rawValue[..<separatorIndex])
        let modelVersion = String(rawValue[rawValue.index(after: separatorIndex)...])
        let compactProjectIdentifier = projectIdentifier.prefix(8)

        return "Project \(compactProjectIdentifier) v\(modelVersion)"
    }
}

private struct DownloadedModelPackage {
    let model: MLModel
    let sampleCount: Int
    let labels: [String]
}

private enum DownloadedModelLoader {
    static func loadPackage(for descriptor: DetectionModelDescriptor) throws -> DownloadedModelPackage {
        guard let archiveURL = descriptor.downloadedArchiveURL else {
            throw LocalSoundDetectionError.invalidDownloadedModel
        }

        let workingDirectory = try preparedWorkingDirectory(for: archiveURL)
        let packageURL = workingDirectory.appendingPathComponent("Model.mlpackage", isDirectory: true)
        let compiledURL = workingDirectory.appendingPathComponent("Model.mlmodelc", isDirectory: true)

        if !FileManager.default.fileExists(atPath: compiledURL.path) {
            try? FileManager.default.removeItem(at: packageURL)
            try? FileManager.default.removeItem(at: compiledURL)
            try ZIPArchiveExtractor.extractArchive(at: archiveURL, to: packageURL)

            let compiledModelURL: URL
            do {
                compiledModelURL = try MLModel.compileModel(at: packageURL)
            } catch {
                throw LocalSoundDetectionError.modelCompilationFailed
            }

            try? FileManager.default.removeItem(at: compiledURL)
            try FileManager.default.copyItem(at: compiledModelURL, to: compiledURL)
        }

        let model = try MLModel(contentsOf: compiledURL)
        guard let waveformDescription = model.modelDescription.inputDescriptionsByName["waveform"],
              let waveformConstraint = waveformDescription.multiArrayConstraint,
              let sampleCount = waveformConstraint.shape.first?.intValue,
              sampleCount > 0,
              model.modelDescription.outputDescriptionsByName["label_probabilities"]?.multiArrayConstraint != nil else {
            throw LocalSoundDetectionError.invalidDownloadedModel
        }

        return DownloadedModelPackage(
            model: model,
            sampleCount: sampleCount,
            labels: descriptor.labelNames
        )
    }

    private static func preparedWorkingDirectory(for archiveURL: URL) throws -> URL {
        let rootDirectory = try modelCacheDirectory()
        let modelDirectory = rootDirectory.appendingPathComponent(archiveURL.deletingPathExtension().lastPathComponent, isDirectory: true)

        if !FileManager.default.fileExists(atPath: modelDirectory.path) {
            try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        }

        return modelDirectory
    }

    private static func modelCacheDirectory() throws -> URL {
        let baseDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = baseDirectory.appendingPathComponent("DownloadedDetectionModels", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }
}

private enum ZIPArchiveExtractor {
    static func extractArchive(at archiveURL: URL, to destinationURL: URL) throws {
        let archiveData = try Data(contentsOf: archiveURL)
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        var offset = 0

        while offset + 4 <= archiveData.count {
            let signature = try archiveData.readUInt32LE(at: offset)
            if signature != 0x04034b50 { break }

            let compressionMethod = Int(try archiveData.readUInt16LE(at: offset + 8))
            let flags = Int(try archiveData.readUInt16LE(at: offset + 6))
            let compressedSize = Int(try archiveData.readUInt32LE(at: offset + 18))
            let uncompressedSize = Int(try archiveData.readUInt32LE(at: offset + 22))
            let fileNameLength = Int(try archiveData.readUInt16LE(at: offset + 26))
            let extraFieldLength = Int(try archiveData.readUInt16LE(at: offset + 28))

            if flags & 0x08 != 0 {
                throw LocalSoundDetectionError.zipArchiveUnsupported
            }

            let headerSize = 30
            let nameStart = offset + headerSize
            let nameEnd = nameStart + fileNameLength
            let dataStart = nameEnd + extraFieldLength
            let dataEnd = dataStart + compressedSize

            guard dataEnd <= archiveData.count,
                  let fileName = String(data: archiveData[nameStart..<nameEnd], encoding: .utf8),
                  !fileName.contains("..") else {
                throw LocalSoundDetectionError.zipArchiveUnsupported
            }

            let outputURL = destinationURL.appendingPathComponent(fileName)
            if fileName.hasSuffix("/") {
                try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
            } else {
                try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                let fileData = archiveData[dataStart..<dataEnd]
                let extractedData: Data

                switch compressionMethod {
                case 0:
                    extractedData = Data(fileData)
                case 8:
                    extractedData = try inflateRaw(Data(fileData), expectedSize: uncompressedSize)
                default:
                    throw LocalSoundDetectionError.zipArchiveUnsupported
                }

                try extractedData.write(to: outputURL, options: .atomic)
            }

            offset = dataEnd
        }
    }

    private static func inflateRaw(_ data: Data, expectedSize: Int) throws -> Data {
        var stream = z_stream()
        let initResult = inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard initResult == Z_OK else {
            throw LocalSoundDetectionError.zipArchiveUnsupported
        }

        defer {
            inflateEnd(&stream)
        }

        let chunkSize = max(16_384, expectedSize)
        var output = Data()

        try data.withUnsafeBytes { rawInputBuffer in
            guard let inputBaseAddress = rawInputBuffer.bindMemory(to: Bytef.self).baseAddress else {
                throw LocalSoundDetectionError.zipArchiveUnsupported
            }

            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: inputBaseAddress)
            stream.avail_in = uInt(data.count)

            var status: Int32 = Z_OK

            while status == Z_OK {
                var chunk = [UInt8](repeating: 0, count: chunkSize)
                status = chunk.withUnsafeMutableBytes { rawOutputBuffer in
                    stream.next_out = rawOutputBuffer.bindMemory(to: Bytef.self).baseAddress
                    stream.avail_out = uInt(chunkSize)
                    return inflate(&stream, Z_NO_FLUSH)
                }

                let producedCount = chunkSize - Int(stream.avail_out)
                if producedCount > 0 {
                    output.append(contentsOf: chunk.prefix(producedCount))
                }
            }

            if status != Z_STREAM_END {
                throw LocalSoundDetectionError.zipArchiveUnsupported
            }
        }

        return output
    }
}

private extension Data {
    func readUInt16LE(at offset: Int) throws -> UInt16 {
        guard offset + 2 <= count else { throw LocalSoundDetectionError.zipArchiveUnsupported }
        let low = UInt16(self[offset])
        let high = UInt16(self[offset + 1]) << 8
        return low | high
    }

    func readUInt32LE(at offset: Int) throws -> UInt32 {
        guard offset + 4 <= count else { throw LocalSoundDetectionError.zipArchiveUnsupported }
        let b0 = UInt32(self[offset])
        let b1 = UInt32(self[offset + 1]) << 8
        let b2 = UInt32(self[offset + 2]) << 16
        let b3 = UInt32(self[offset + 3]) << 24
        return b0 | b1 | b2 | b3
    }
}

private enum DownloadedWaveformPreprocessor {
    static func loadMonoWaveform(from fileURL: URL, targetSampleRate: Double) throws -> [Float] {
        let audioFile = try AVAudioFile(forReading: fileURL)
        let sourceFormat = audioFile.processingFormat

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ),
        let converter = AVAudioConverter(from: sourceFormat, to: targetFormat),
        let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: AVAudioFrameCount(audioFile.length))
        else {
            throw LocalSoundDetectionError.audioConversionFailed
        }

        try audioFile.read(into: sourceBuffer)

        let expectedFrameCount = max(
            Int((Double(sourceBuffer.frameLength) * targetSampleRate / sourceFormat.sampleRate).rounded(.up)),
            1
        )

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: AVAudioFrameCount(expectedFrameCount + 1024)
        ) else {
            throw LocalSoundDetectionError.audioConversionFailed
        }

        var hasConsumedInput = false
        var conversionError: NSError?
        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if hasConsumedInput {
                outStatus.pointee = .endOfStream
                return nil
            }

            hasConsumedInput = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        if conversionError != nil || status == .error {
            throw LocalSoundDetectionError.audioConversionFailed
        }

        guard let channelData = outputBuffer.floatChannelData?.pointee else {
            throw LocalSoundDetectionError.audioConversionFailed
        }

        return Array(UnsafeBufferPointer(start: channelData, count: Int(outputBuffer.frameLength)))
    }
}

private enum PeakCenteredInference {
    static func recognizeEvents(
        in recording: CompletedRecording,
        with package: DownloadedModelPackage
    ) throws -> [DetectionEvent] {
        let targetSampleRate = 16_000.0
        let waveform = try DownloadedWaveformPreprocessor.loadMonoWaveform(
            from: recording.fileURL,
            targetSampleRate: targetSampleRate
        )

        guard !waveform.isEmpty else { return [] }

        let peakIndices = peakCenters(in: waveform, sampleCount: package.sampleCount)
        let slices = peakIndices.map { extractWindow(from: waveform, centerIndex: $0, sampleCount: package.sampleCount) }
        let labels = package.labels

        let rawEvents = try slices.enumerated().compactMap { index, slice -> DetectionEvent? in
            let probabilities = try predictProbabilities(for: slice, model: package.model)
            guard let best = probabilities.enumerated().max(by: { $0.element < $1.element }) else {
                return nil
            }

            let label = labels.indices.contains(best.offset) ? labels[best.offset] : "Class \(best.offset + 1)"
            let midpoint = Double(peakIndices[index]) / targetSampleRate
            let halfWindowDuration = Double(package.sampleCount) / targetSampleRate / 2
            let startTime = max(0, midpoint - halfWindowDuration)
            let endTime = min(recording.audioEndTimestamp, midpoint + halfWindowDuration)

            return DetectionEvent(
                id: "\(label)-\(index)",
                title: label,
                startTime: startTime,
                endTime: endTime,
                confidence: Double(best.element)
            )
        }

        return mergedEvents(from: rawEvents)
    }

    private static func peakCenters(in waveform: [Float], sampleCount: Int) -> [Int] {
        if waveform.count <= sampleCount {
            return [waveform.count / 2]
        }

        let blockSize = max(128, sampleCount / 32)
        var blockPeaks: [(index: Int, amplitude: Float)] = []
        blockPeaks.reserveCapacity((waveform.count / blockSize) + 1)

        for blockStart in stride(from: 0, to: waveform.count, by: blockSize) {
            let blockEnd = min(blockStart + blockSize, waveform.count)
            var peakIndex = blockStart
            var peakAmplitude: Float = 0

            for sampleIndex in blockStart..<blockEnd {
                let amplitude = abs(waveform[sampleIndex])
                if amplitude > peakAmplitude {
                    peakAmplitude = amplitude
                    peakIndex = sampleIndex
                }
            }

            blockPeaks.append((peakIndex, peakAmplitude))
        }

        guard let maxAmplitude = blockPeaks.map(\.amplitude).max(), maxAmplitude > 0 else {
            return [waveform.count / 2]
        }

        let threshold = maxAmplitude * 0.35
        let minimumDistance = max(sampleCount / 2, blockSize)
        var accepted: [(index: Int, amplitude: Float)] = []

        for candidate in blockPeaks.sorted(by: { $0.amplitude > $1.amplitude }) where candidate.amplitude >= threshold {
            if accepted.allSatisfy({ abs($0.index - candidate.index) >= minimumDistance }) {
                accepted.append(candidate)
            }
            if accepted.count == 8 {
                break
            }
        }

        if accepted.isEmpty, let loudest = blockPeaks.max(by: { $0.amplitude < $1.amplitude }) {
            accepted = [loudest]
        }

        return accepted.map(\.index).sorted()
    }

    private static func extractWindow(from waveform: [Float], centerIndex: Int, sampleCount: Int) -> [Float] {
        var slice = [Float](repeating: 0, count: sampleCount)
        let halfWindow = sampleCount / 2
        let desiredStart = centerIndex - halfWindow
        let copyStart = max(0, desiredStart)
        let copyEnd = min(waveform.count, desiredStart + sampleCount)
        let destinationStart = max(0, -desiredStart)

        if copyStart < copyEnd {
            slice.replaceSubrange(
                destinationStart..<(destinationStart + (copyEnd - copyStart)),
                with: waveform[copyStart..<copyEnd]
            )
        }

        return slice
    }

    private static func predictProbabilities(for waveform: [Float], model: MLModel) throws -> [Float] {
        let inputArray = try MLMultiArray(shape: [NSNumber(value: waveform.count)], dataType: .float32)
        for (index, value) in waveform.enumerated() {
            inputArray[index] = NSNumber(value: value)
        }

        let provider = try MLDictionaryFeatureProvider(dictionary: ["waveform": MLFeatureValue(multiArray: inputArray)])
        let prediction = try model.prediction(from: provider)

        guard let outputArray = prediction.featureValue(for: "label_probabilities")?.multiArrayValue else {
            throw LocalSoundDetectionError.invalidModelOutput
        }

        return (0..<outputArray.count).map { outputArray[$0].floatValue }
    }

    private static func mergedEvents(from events: [DetectionEvent]) -> [DetectionEvent] {
        let sortedEvents = events.sorted { $0.startTime < $1.startTime }
        guard !sortedEvents.isEmpty else { return [] }

        var merged: [DetectionEvent] = []

        for event in sortedEvents {
            if let last = merged.last,
               last.title == event.title,
               event.startTime - last.endTime <= 0.2 {
                merged[merged.count - 1] = DetectionEvent(
                    id: last.id,
                    title: last.title,
                    startTime: last.startTime,
                    endTime: max(last.endTime, event.endTime),
                    confidence: max(last.confidence, event.confidence)
                )
            } else {
                merged.append(event)
            }
        }

        return merged
    }
}

struct BundledEventDetectionService: EventDetectionServicing {
    let fallbackService: any EventDetectionServicing

    init(fallbackService: any EventDetectionServicing = MockEventDetectionService()) {
        self.fallbackService = fallbackService
    }

    func recognizeEvents(
        in recording: CompletedRecording,
        model: DetectionModelDescriptor
    ) async throws -> [DetectionEvent] {
        if model.downloadedArchiveURL != nil {
            let package = try DownloadedModelLoader.loadPackage(for: model)
            return try PeakCenteredInference.recognizeEvents(in: recording, with: package)
        }

        guard let bundledModelName = model.bundledModelName else {
            return try await fallbackService.recognizeEvents(in: recording, model: model)
        }

        guard let modelURL = Bundle.main.url(forResource: bundledModelName, withExtension: "mlmodelc") else {
            return try await fallbackService.recognizeEvents(in: recording, model: model)
        }

        let mlModel = try MLModel(contentsOf: modelURL)
        let request = try SNClassifySoundRequest(mlModel: mlModel)
        let analyzer = try SNAudioFileAnalyzer(url: recording.fileURL)
        let observer = FileSoundAnalysisObserver()

        return try await withCheckedThrowingContinuation { continuation in
            observer.onFinish = {
                let events = observer.makeEvents()

                if events.isEmpty {
                    continuation.resume(throwing: LocalSoundDetectionError.noResultsProduced)
                } else {
                    continuation.resume(returning: events)
                }
            }
            observer.onError = { error in
                continuation.resume(throwing: error)
            }

            do {
                try analyzer.add(request, withObserver: observer)
                analyzer.analyze { _ in
                    observer.onFinish?()
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

final class FileSoundAnalysisObserver: NSObject, SNResultsObserving {
    struct Observation {
        let identifier: String
        let confidence: Double
        let startTime: Double
        let endTime: Double
    }

    var onFinish: (() -> Void)?
    var onError: ((Error) -> Void)?

    private(set) var observations: [Observation] = []

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let classificationResult = result as? SNClassificationResult,
              let topClassification = classificationResult.classifications.first else { return }

        let start = classificationResult.timeRange.start.seconds
        let duration = classificationResult.timeRange.duration.seconds

        observations.append(
            Observation(
                identifier: topClassification.identifier,
                confidence: Double(topClassification.confidence),
                startTime: start,
                endTime: start + duration
            )
        )
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        onError?(error)
    }

    func makeEvents() -> [DetectionEvent] {
        let filtered = observations.filter { observation in
            observation.confidence >= 0.35 &&
            observation.identifier.caseInsensitiveCompare("background") != .orderedSame
        }

        let source = filtered.isEmpty ? observations : filtered
        guard !source.isEmpty else { return [] }

        var merged: [Observation] = []

        for observation in source.sorted(by: { $0.startTime < $1.startTime }) {
            if let last = merged.last,
               last.identifier == observation.identifier,
               observation.startTime - last.endTime < 0.35 {
                merged[merged.count - 1] = Observation(
                    identifier: last.identifier,
                    confidence: max(last.confidence, observation.confidence),
                    startTime: last.startTime,
                    endTime: max(last.endTime, observation.endTime)
                )
            } else {
                merged.append(observation)
            }
        }

        return merged.enumerated().map { index, observation in
            DetectionEvent(
                id: "\(observation.identifier)-\(index)",
                title: observation.identifier,
                startTime: observation.startTime,
                endTime: observation.endTime,
                confidence: observation.confidence
            )
        }
    }
}

struct WaveformLoader {
    func loadSamples(from fileURL: URL, sampleCount: Int = 120) throws -> [Double] {
        let audioFile = try AVAudioFile(forReading: fileURL)
        let frameCount = AVAudioFrameCount(audioFile.length)

        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameCount) else {
            return []
        }

        try audioFile.read(into: buffer)

        guard let channelData = buffer.floatChannelData else {
            return []
        }

        let channelCount = Int(audioFile.processingFormat.channelCount)
        let sampleTotal = Int(buffer.frameLength)
        let bucketSize = max(1, sampleTotal / sampleCount)
        var peaks: [Double] = []
        peaks.reserveCapacity(sampleCount)

        for bucketStart in stride(from: 0, to: sampleTotal, by: bucketSize) {
            let bucketEnd = min(bucketStart + bucketSize, sampleTotal)
            var peak: Float = 0

            for frame in bucketStart..<bucketEnd {
                var mixedSample: Float = 0

                for channel in 0..<channelCount {
                    mixedSample += abs(channelData[channel][frame])
                }

                peak = max(peak, mixedSample / Float(channelCount))
            }

            peaks.append(Double(peak))
        }

        guard let maxPeak = peaks.max(), maxPeak > 0 else {
            return Array(repeating: 0.05, count: peaks.count)
        }

        return peaks.map { max(0.04, $0 / maxPeak) }
    }
}
