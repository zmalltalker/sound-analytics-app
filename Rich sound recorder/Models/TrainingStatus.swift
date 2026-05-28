//
//  TrainingStatus.swift
//  Rich sound recorder
//
//  Created by Codex on 12/05/2026.
//

import Foundation

struct TrainingRequest {
    let requestUID: String

    init(requestUID: String) {
        self.requestUID = requestUID
    }
}

struct TrainingStatusSnapshot {
    let status: String

    init(status: String) {
        self.status = status
    }
}

struct TrainingStatusReport: Decodable, Identifiable {
    let status: String
    let message: String?
    let createdAt: String?

    var id: String {
        [status, createdAt ?? "", message ?? ""].joined(separator: "|")
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case message
        case created_at
        case creation_timestamp
        case timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(String.self, forKey: .status)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        createdAt =
            Self.decodeStringIfPresent(from: container, forKey: .created_at) ??
            Self.decodeStringIfPresent(from: container, forKey: .creation_timestamp) ??
            Self.decodeStringIfPresent(from: container, forKey: .timestamp)
    }

    private static func decodeStringIfPresent(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> String? {
        if let value = try? container.decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        return nil
    }
}
