//
//  Label.swift
//  Rich sound recorder
//
//  Created by Marius Mathiesen on 18/03/2026.
//

import Foundation

struct RecorderLabel: Identifiable, Codable {
    let uid: String
    let guid: String
    let name: String
    let user_id: String
    let duration: Double
    let description: String

    var id: String { uid }
}
