//
//  RecordingClip.swift
//  Rich sound recorder
//
//  Created by Codex on 19/03/2026.
//

import Foundation

struct RecordingClip: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let startTimestamp: Double?
    let endTimestamp: Double?
    let labelUID: String?
    let samplesHex: String?
    let sampleRate: Double?
    let dataVersion: String?

    init(record: AnnotatedAudioDataRecord) {
        let eventDetails = EventLabelDetails(jsonString: record.eventLabel)

        id = record.audioSnippet.dataID
        title = record.audioSnippet.dataID

        let subtitleParts = [
            eventDetails.eventType,
            eventDetails.timeRangeText,
            record.audioSnippet.inputTotalPeriod.map { "Period: \($0)" },
            record.audioSnippet.theoreticalSampleRate.map { "Rate: \($0) Hz" },
            "Quality: \(record.audioSnippet.quality)"
        ].compactMap { $0 }

        subtitle = subtitleParts.isEmpty ? nil : subtitleParts.joined(separator: "  ·  ")
        startTimestamp = eventDetails.startTimestamp
        endTimestamp = eventDetails.endTimestamp
        labelUID = nil
        samplesHex = record.audioSnippet.inputSamples
        sampleRate = record.audioSnippet.theoreticalSampleRate.map(Double.init)
        dataVersion = record.audioSnippet.dataVersion
    }

    init?(jsonObject: Any) {
        guard let dictionary = jsonObject as? [String: Any] else { return nil }

        let idValue =
            RecordingClip.stringValue(from: dictionary["uid"]) ??
            RecordingClip.stringValue(from: dictionary["guid"]) ??
            RecordingClip.stringValue(from: dictionary["id"]) ??
            UUID().uuidString.lowercased()

        let titleValue =
            RecordingClip.stringValue(from: dictionary["filename"]) ??
            RecordingClip.stringValue(from: dictionary["file_name"]) ??
            RecordingClip.stringValue(from: dictionary["name"]) ??
            RecordingClip.stringValue(from: dictionary["uid"]) ??
            "Clip"

        let labelUIDValue =
            RecordingClip.stringValue(from: dictionary["label_uid"]) ??
            RecordingClip.stringValue(from: dictionary["labelUid"])

        let startTimestampValue =
            RecordingClip.doubleValue(from: dictionary["start_timestamp"]) ??
            RecordingClip.doubleValue(from: dictionary["start"])

        let endTimestampValue =
            RecordingClip.doubleValue(from: dictionary["end_timestamp"]) ??
            RecordingClip.doubleValue(from: dictionary["end"]) ??
            RecordingClip.doubleValue(from: dictionary["audio_end_timestamp"])

        let subtitleParts = [
            labelUIDValue.map { "Label: \($0)" },
            startTimestampValue.map { "Start: \(RecordingClip.formattedTimestamp($0))" },
            endTimestampValue.map { "End: \(RecordingClip.formattedTimestamp($0))" }
        ].compactMap { $0 }

        id = idValue
        title = titleValue
        subtitle = subtitleParts.isEmpty ? nil : subtitleParts.joined(separator: "  ·  ")
        startTimestamp = startTimestampValue
        endTimestamp = endTimestampValue
        labelUID = labelUIDValue
        samplesHex = nil
        sampleRate = nil
        dataVersion = nil
    }

    private static func stringValue(from value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private static func doubleValue(from value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string)
        default:
            return nil
        }
    }

    private static func formattedTimestamp(_ value: Double) -> String {
        if value.rounded(.towardZero) == value {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }
}

private struct EventLabelDetails {
    let eventType: String?
    let startTimestamp: Double?
    let endTimestamp: Double?

    init(jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            eventType = nil
            startTimestamp = nil
            endTimestamp = nil
            return
        }

        eventType = jsonObject["__type__"] as? String
        startTimestamp = Self.extractTimestamp(from: jsonObject["start_atom"])
        endTimestamp = Self.extractTimestamp(from: jsonObject["end_atom"])
    }

    var timeRangeText: String? {
        guard let startTimestamp, let endTimestamp else { return nil }
        return "\(Self.formattedTimestamp(startTimestamp))s-\(Self.formattedTimestamp(endTimestamp))s"
    }

    private static func extractTimestamp(from value: Any?) -> Double? {
        guard let dictionary = value as? [String: Any] else { return nil }
        if let number = dictionary["timestamp"] as? NSNumber {
            return number.doubleValue
        }
        if let string = dictionary["timestamp"] as? String {
            return Double(string)
        }
        return nil
    }

    private static func formattedTimestamp(_ value: Double) -> String {
        if value.rounded(.towardZero) == value {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }
}
