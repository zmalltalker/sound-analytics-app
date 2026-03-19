//
//  RecordingListRepository.swift
//  Rich sound recorder
//
//  Created by Codex on 19/03/2026.
//

import Foundation

@MainActor
class RecordingListRepository {
    private let apiService: APIService

    init(loginService: AuthenticationService) {
        self.apiService = APIService(loginService: loginService)
    }

    func list(start: Int = 0, end: Int = Int(Date().timeIntervalSince1970), labelUID: String? = nil) async throws -> [RecordingClip] {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "start", value: String(start)),
            URLQueryItem(name: "end", value: String(end))
        ]

        if let labelUID {
            components.queryItems?.append(URLQueryItem(name: "label_uid", value: labelUID))
        }

        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""
        let response = try await apiService.getResponse(
            path: "data_download/annotated_snippets\(query)",
            acceptHeader: nil
        )

        debugResponse(response)

        if let avroRecords = try? AvroContainerHeader.decodeAnnotatedAudioDataRecords(from: response.data) {
            print("   Avro records decoded: \(avroRecords.count)")
            for (index, record) in avroRecords.prefix(3).enumerated() {
                let samplesPreview: String
                if let inputSamples = record.audioSnippet.inputSamples {
                    let prefix = String(inputSamples.prefix(120))
                    let middleStart = max(0, (inputSamples.count / 2) - 60)
                    let middleEnd = min(inputSamples.count, middleStart + 120)
                    let middle = String(inputSamples[inputSamples.index(inputSamples.startIndex, offsetBy: middleStart)..<inputSamples.index(inputSamples.startIndex, offsetBy: middleEnd)])
                    let suffix = String(inputSamples.suffix(120))
                    let distinctCharacters = Set(inputSamples.prefix(4000)).sorted()
                    let distinctPreview = String(distinctCharacters.prefix(20))
                    let decodedDoubles = decodeHexDoublesPreview(from: inputSamples)

                    samplesPreview = """
                    present (\(inputSamples.count) chars)
                     start=\(prefix)
                     middle=\(middle)
                     end=\(suffix)
                     distinct(first 4000)=\(distinctPreview)
                     doubles(first 8)=\(decodedDoubles)
                    """
                } else {
                    samplesPreview = "nil"
                }

                print("   Record \(index + 1): data_id=\(record.audioSnippet.dataID), event_label=\(record.eventLabel), total_period=\(record.audioSnippet.inputTotalPeriod ?? "nil"), sample_rate=\(record.audioSnippet.theoreticalSampleRate?.description ?? "nil"), quality=\(record.audioSnippet.quality), input_samples=\(samplesPreview)")
            }
            let deduplicatedRecords = deduplicateByDataID(records: avroRecords)
            print("   Avro records after deduplication: \(deduplicatedRecords.count)")
            return deduplicatedRecords.map(RecordingClip.init(record:))
        }

        let jsonObject = try JSONSerialization.jsonObject(with: response.data)
        guard let array = jsonObject as? [Any] else { return [] }

        return array.compactMap(RecordingClip.init(jsonObject:))
    }

    private func debugResponse(_ response: APIService.APIResponse) {
        let contentType = response.httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown"
        let utf8Preview = String(data: response.data.prefix(200), encoding: .utf8)
        let hexPreview = response.data.prefix(32).map { String(format: "%02x", $0) }.joined(separator: " ")

        print("🧪 Clips response debug:")
        print("   Content-Type: \(contentType)")
        print("   Bytes: \(response.data.count)")
        if let utf8Preview, !utf8Preview.isEmpty {
            print("   UTF-8 preview: \(utf8Preview)")
        } else {
            print("   UTF-8 preview: <not decodable>")
        }
        print("   Hex preview: \(hexPreview)")

        do {
            let header = try AvroContainerHeader.parse(from: response.data)
            print("   Avro codec: \(header.codec ?? "unknown")")
            if let schema = header.schema {
                print("   Avro schema: \(schema)")
            } else {
                print("   Avro schema: <missing>")
            }
        } catch {
            print("   Avro header parse: failed (\(error))")
        }
    }

    private func decodeHexDoublesPreview(from hexString: String) -> String {
        let previewLength = min(hexString.count, 16 * 8)
        let previewHex = String(hexString.prefix(previewLength))
        guard previewHex.count.isMultiple(of: 16) else { return "invalid hex length" }

        var values: [String] = []
        var index = previewHex.startIndex

        while index < previewHex.endIndex {
            let nextIndex = previewHex.index(index, offsetBy: 16)
            let chunk = String(previewHex[index..<nextIndex])

            guard let data = hexData(from: chunk), data.count == 8 else {
                return "failed to decode hex"
            }

            let bitPattern = data.withUnsafeBytes { buffer in
                buffer.load(as: UInt64.self)
            }
            let value = Double(bitPattern: UInt64(littleEndian: bitPattern))
            values.append(String(format: "%.6f", value))
            index = nextIndex
        }

        return values.joined(separator: ", ")
    }

    private func hexData(from string: String) -> Data? {
        guard string.count.isMultiple(of: 2) else { return nil }

        var data = Data()
        var index = string.startIndex

        while index < string.endIndex {
            let nextIndex = string.index(index, offsetBy: 2)
            let byteString = string[index..<nextIndex]
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }

        return data
    }

    private func deduplicateByDataID(records: [AnnotatedAudioDataRecord]) -> [AnnotatedAudioDataRecord] {
        var latestByDataID: [String: AnnotatedAudioDataRecord] = [:]
        var orderedDataIDs: [String] = []

        for record in records {
            let dataID = record.audioSnippet.dataID
            if latestByDataID[dataID] == nil {
                orderedDataIDs.append(dataID)
            }
            latestByDataID[dataID] = record
        }

        return orderedDataIDs.compactMap { latestByDataID[$0] }
    }
}
