//
//  Project.swift
//  Rich sound recorder
//
//  Created by Marius Mathiesen on 18/03/2026.
//

import Foundation

struct Project: Identifiable, Codable {
    let uid: String
    let name: String
    let description: String
    let owner_uid: String
    let labels: String
    let guests_uids: String
    let input_download_response: String?

    var id: String { uid }

    var labelUIDs: [String] {
        parseJSONArray(from: labels)
    }

    var guestUIDs: [String] {
        parseJSONArray(from: guests_uids)
    }

    private func parseJSONArray(from value: String) -> [String] {
        guard let data = value.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}
