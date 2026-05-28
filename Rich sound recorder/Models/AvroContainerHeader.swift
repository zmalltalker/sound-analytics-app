//
//  AvroContainerHeader.swift
//  Rich sound recorder
//
//  Created by Codex on 19/03/2026.
//

import Foundation
import zlib

struct AvroContainerHeader {
    let metadata: [String: Data]
    let syncMarker: Data

    var codec: String? {
        metadata["avro.codec"].flatMap { String(data: $0, encoding: .utf8) }
    }

    var schema: String? {
        metadata["avro.schema"].flatMap { String(data: $0, encoding: .utf8) }
    }

    static func parse(from data: Data) throws -> AvroContainerHeader {
        try parseContainer(from: data).header
    }

    static func decodeAnnotatedAudioDataRecords(from data: Data) throws -> [AnnotatedAudioDataRecord] {
        var container = try parseContainer(from: data)
        let codec = container.header.codec ?? "null"
        var records: [AnnotatedAudioDataRecord] = []

        while !container.parser.isAtEnd {
            let recordCount = try container.parser.readLong()
            if recordCount == 0 { continue }

            let blockSize = try container.parser.readLong()
            guard recordCount >= 0, blockSize >= 0 else {
                throw AvroContainerHeaderError.invalidBlock
            }

            let blockData = try container.parser.read(count: Int(blockSize))
            let blockSyncMarker = try container.parser.read(count: 16)
            guard blockSyncMarker == container.header.syncMarker else {
                throw AvroContainerHeaderError.invalidSyncMarker
            }

            let decompressedBlock = try decompressBlock(blockData, codec: codec)
            var blockParser = AvroBinaryParser(data: decompressedBlock)

            for _ in 0..<recordCount {
                records.append(try AnnotatedAudioDataRecord.decode(from: &blockParser))
            }
        }

        return records
    }

    private static func parseContainer(from data: Data) throws -> (header: AvroContainerHeader, parser: AvroBinaryParser) {
        var parser = AvroBinaryParser(data: data)

        let magic = try parser.read(count: 4)
        guard magic == Data([0x4f, 0x62, 0x6a, 0x01]) else {
            throw AvroContainerHeaderError.invalidMagic
        }

        var metadata: [String: Data] = [:]

        while true {
            let blockCount = try parser.readLong()
            if blockCount == 0 { break }

            let entryCount: Int
            if blockCount < 0 {
                _ = try parser.readLong()
                entryCount = Int(-blockCount)
            } else {
                entryCount = Int(blockCount)
            }

            for _ in 0..<entryCount {
                let key = try parser.readString()
                let value = try parser.readBytes()
                metadata[key] = value
            }
        }

        let syncMarker = try parser.read(count: 16)
        return (AvroContainerHeader(metadata: metadata, syncMarker: syncMarker), parser)
    }

    private static func decompressBlock(_ data: Data, codec: String) throws -> Data {
        switch codec {
        case "", "null":
            return data
        case "deflate":
            return try inflateRawDeflate(data)
        default:
            throw AvroContainerHeaderError.unsupportedCodec(codec)
        }
    }

    private static func inflateRawDeflate(_ data: Data) throws -> Data {
        guard !data.isEmpty else { return Data() }

        var stream = z_stream()
        let initStatus = inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard initStatus == Z_OK else {
            throw AvroContainerHeaderError.decompressionFailed(initStatus)
        }

        defer {
            inflateEnd(&stream)
        }

        return try data.withUnsafeBytes { sourceBuffer in
            guard let sourceBaseAddress = sourceBuffer.bindMemory(to: Bytef.self).baseAddress else {
                return Data()
            }

            stream.next_in = UnsafeMutablePointer(mutating: sourceBaseAddress)
            stream.avail_in = uInt(sourceBuffer.count)

            let chunkSize = 64 * 1024
            var output = Data()

            repeat {
                var chunk = [UInt8](repeating: 0, count: chunkSize)
                let status = chunk.withUnsafeMutableBufferPointer { chunkBuffer in
                    stream.next_out = chunkBuffer.baseAddress
                    stream.avail_out = uInt(chunkSize)
                    return inflate(&stream, Z_NO_FLUSH)
                }

                let produced = chunkSize - Int(stream.avail_out)
                if produced > 0 {
                    output.append(contentsOf: chunk.prefix(produced))
                }

                if status == Z_STREAM_END {
                    return output
                }

                guard status == Z_OK else {
                    throw AvroContainerHeaderError.decompressionFailed(status)
                }
            } while true
        }
    }
}

struct AnnotatedAudioDataRecord {
    let inputDownloadResponse: String
    let audioSnippet: AudioSnippetRecord
    let eventLabel: String

    struct AudioSnippetRecord {
        let inputDownloadResponse: String
        let dataID: String
        let dataVersion: String
        let inputSamples: String?
        let inputTotalPeriod: String?
        let theoreticalSampleRate: Int64?
        let inputNanFillValue: String
        let quality: Int64
    }

    static func decode(from parser: inout AvroBinaryParser) throws -> AnnotatedAudioDataRecord {
        let inputDownloadResponse = try parser.readString()
        let audioSnippet = try AudioSnippetRecord.decode(from: &parser)
        let eventLabel = try parser.readString()

        return AnnotatedAudioDataRecord(
            inputDownloadResponse: inputDownloadResponse,
            audioSnippet: audioSnippet,
            eventLabel: eventLabel
        )
    }
}

private extension AnnotatedAudioDataRecord.AudioSnippetRecord {
    static func decode(from parser: inout AvroBinaryParser) throws -> Self {
        Self(
            inputDownloadResponse: try parser.readString(),
            dataID: try parser.readString(),
            dataVersion: try parser.readString(),
            inputSamples: try parser.readNullableString(),
            inputTotalPeriod: try parser.readNullableString(),
            theoreticalSampleRate: try parser.readNullableLong(),
            inputNanFillValue: try parser.readString(),
            quality: try parser.readLong()
        )
    }
}

enum AvroContainerHeaderError: Error {
    case invalidMagic
    case truncated
    case invalidString
    case invalidUnionIndex(Int64)
    case invalidBlock
    case invalidSyncMarker
    case unsupportedCodec(String)
    case decompressionFailed(Int32)
}

struct AvroBinaryParser {
    let data: Data
    var offset: Int = 0

    init(data: Data) {
        self.data = data
    }

    var isAtEnd: Bool {
        offset >= data.count
    }

    mutating func read(count: Int) throws -> Data {
        guard count >= 0, offset + count <= data.count else {
            throw AvroContainerHeaderError.truncated
        }
        let chunk = data.subdata(in: offset..<(offset + count))
        offset += count
        return chunk
    }

    mutating func readLong() throws -> Int64 {
        var shift: UInt64 = 0
        var result: UInt64 = 0

        while true {
            guard offset < data.count else { throw AvroContainerHeaderError.truncated }
            let byte = data[offset]
            offset += 1

            result |= UInt64(byte & 0x7f) << shift
            if (byte & 0x80) == 0 { break }
            shift += 7
            if shift > 63 { throw AvroContainerHeaderError.truncated }
        }

        let value = Int64(bitPattern: result >> 1) ^ -Int64(bitPattern: result & 1)
        return value
    }

    mutating func readBytes() throws -> Data {
        let length = try readLong()
        guard length >= 0 else { throw AvroContainerHeaderError.truncated }
        return try read(count: Int(length))
    }

    mutating func readString() throws -> String {
        let bytes = try readBytes()
        guard let string = String(data: bytes, encoding: .utf8) else {
            throw AvroContainerHeaderError.invalidString
        }
        return string
    }

    mutating func readNullableString() throws -> String? {
        switch try readLong() {
        case 0:
            return nil
        case 1:
            return try readString()
        case let index:
            throw AvroContainerHeaderError.invalidUnionIndex(index)
        }
    }

    mutating func readNullableLong() throws -> Int64? {
        switch try readLong() {
        case 0:
            return nil
        case 1:
            return try readLong()
        case let index:
            throw AvroContainerHeaderError.invalidUnionIndex(index)
        }
    }
}
