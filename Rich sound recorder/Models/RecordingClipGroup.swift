//
//  RecordingClipGroup.swift
//  Rich sound recorder
//
//  Created by Codex on 19/03/2026.
//

import Foundation

struct RecordingClipGroup: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let versions: [RecordingClip]

    var versionsCountText: String {
        "\(versions.count) version\(versions.count == 1 ? "" : "s")"
    }

    init(versions: [RecordingClip]) {
        precondition(!versions.isEmpty, "RecordingClipGroup requires at least one version")
        self.versions = versions
        id = versions[0].id
        title = versions[0].title
        subtitle = versions.last?.subtitle
    }
}
