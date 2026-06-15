//
//  CompletedRecording.swift
//  Rich sound recorder
//
//  Created by Codex on 19/03/2026.
//

import Foundation

struct CompletedRecording {
    let fileURL: URL
    let startTimestamp: Double
    let endTimestamp: Double
    let audioEndTimestamp: Double
}
