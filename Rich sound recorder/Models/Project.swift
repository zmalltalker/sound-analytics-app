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
}
