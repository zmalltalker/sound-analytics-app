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
        case header
        case status
        case message
        case created_at
        case creation_timestamp
        case timestamp
    }

    private enum HeaderCodingKeys: String, CodingKey {
        case created
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try Self.decodeStatus(from: container, forKey: .status)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        createdAt =
            Self.decodeStringIfPresent(from: container, forKey: .created_at) ??
            Self.decodeStringIfPresent(from: container, forKey: .creation_timestamp) ??
            Self.decodeStringIfPresent(from: container, forKey: .timestamp) ??
            Self.decodeHeaderCreatedIfPresent(from: container)
    }

    private static func decodeStatus(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> String {
        if let value = try? container.decode(String.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? container.decode(Double.self, forKey: key) {
            return String(value)
        }
        throw DecodingError.typeMismatch(
            String.self,
            DecodingError.Context(
                codingPath: container.codingPath + [key],
                debugDescription: "Expected status to be a string or number."
            )
        )
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

    private static func decodeHeaderCreatedIfPresent(
        from container: KeyedDecodingContainer<CodingKeys>
    ) -> String? {
        guard let headerContainer = try? container.nestedContainer(keyedBy: HeaderCodingKeys.self, forKey: .header) else {
            return nil
        }
        if let value = try? headerContainer.decodeIfPresent(String.self, forKey: .created) {
            return value
        }
        if let value = try? headerContainer.decodeIfPresent(Double.self, forKey: .created) {
            return String(value)
        }
        if let value = try? headerContainer.decodeIfPresent(Int.self, forKey: .created) {
            return String(value)
        }
        return nil
    }
}
