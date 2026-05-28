//
//  ProjectModelSpecs.swift
//  Rich sound recorder
//
//  Created by Codex on 28/04/2026.
//

import Foundation

struct ProjectModelSpecs: Codable {
    let label_dict: [String: String]
    let trained_sample_size: Int?
}
