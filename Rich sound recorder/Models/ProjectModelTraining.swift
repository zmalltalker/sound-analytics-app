//
//  ProjectModelTraining.swift
//  Rich sound recorder
//
//  Created by Codex on 15/05/2026.
//

import Foundation

enum TrainingStatus: Equatable, Decodable {
    case success
    case failed
    case inProgress
    case missing
    case unknown(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = TrainingStatus(rawValue: try container.decode(String.self))
    }

    init(rawValue: String) {
        switch rawValue.uppercased() {
        case "SUCCESS":
            self = .success
        case "FAILED":
            self = .failed
        case "IN_PROGRESS":
            self = .inProgress
        case "MISSING":
            self = .missing
        default:
            self = .unknown(rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case .success:
            return "SUCCESS"
        case .failed:
            return "FAILED"
        case .inProgress:
            return "IN_PROGRESS"
        case .missing:
            return "MISSING"
        case .unknown(let value):
            return value
        }
    }

    var displayName: String {
        switch self {
        case .success:
            return "Success"
        case .failed:
            return "Failed"
        case .inProgress:
            return "In progress"
        case .missing:
            return "Missing"
        case .unknown(let value):
            return value
        }
    }

    var isTerminal: Bool {
        self == .success || self == .failed
    }
}

struct TrainingRequest: Decodable {
    let requestUID: String

    enum CodingKeys: String, CodingKey {
        case requestUID = "request_uid"
        case uid
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let uid = try? container.decode(String.self) {
            requestUID = uid
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        requestUID = try container.decodeIfPresent(String.self, forKey: .requestUID)
            ?? container.decode(String.self, forKey: .uid)
    }
}

struct TrainingStatusReport: Identifiable, Decodable {
    let id = UUID()
    let status: TrainingStatus
    let message: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case status
        case message
        case createdAt = "created_at"
        case creationTimestamp = "creation_timestamp"
        case timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(TrainingStatus.self, forKey: .status)
        message = try container.decodeIfPresent(String.self, forKey: .message)

        let dateString = try container.decodeIfPresent(String.self, forKey: .createdAt)
            ?? container.decodeIfPresent(String.self, forKey: .creationTimestamp)
            ?? container.decodeIfPresent(String.self, forKey: .timestamp)
        createdAt = dateString.flatMap(Self.parseDate)
    }

    private nonisolated static func parseDate(_ value: String) -> Date? {
        if let date = ISO8601DateFormatter().date(from: value) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return formatter.date(from: value)
    }
}

struct ProjectModelSpecs: Decodable {
    let labelDict: [String: String]
    let trainedSampleSize: Int?

    enum CodingKeys: String, CodingKey {
        case labelDict = "label_dict"
        case trainedSampleSize = "trained_sample_size"
    }
}
