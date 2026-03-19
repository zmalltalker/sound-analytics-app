//
//  RecordingClipViews.swift
//  Rich sound recorder
//
//  Created by Codex on 19/03/2026.
//

import SwiftUI

struct RecordingClipGroupRow: View {
    let clipGroup: RecordingClipGroup
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Text(clipGroup.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                if let subtitle = clipGroup.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(clipGroup.versionsCountText)
                    .font(.caption2)
                    .foregroundStyle(.cyan)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

struct RecordingVersionsSheet: View {
    let clipGroup: RecordingClipGroup
    let onExport: (RecordingClip) -> Void
    let onPlay: (RecordingClip) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Recording") {
                    Text(clipGroup.title)
                        .foregroundStyle(.primary)
                    Text(clipGroup.versionsCountText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.white.opacity(0.06))

                Section("Versions") {
                    ForEach(Array(clipGroup.versions.enumerated()), id: \.offset) { index, clip in
                        RecordingVersionRow(
                            index: index,
                            clip: clip,
                            onExport: { onExport(clip) },
                            onPlay: { onPlay(clip) }
                        )
                    }
                }
                .listRowBackground(Color.white.opacity(0.06))
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Versions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.cyan)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }
}

private struct RecordingVersionRow: View {
    let index: Int
    let clip: RecordingClip
    let onExport: () -> Void
    let onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Version \(index + 1)")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)

            if let dataVersion = clip.dataVersion {
                Text(dataVersion)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let subtitle = clip.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if clip.canExportAudio {
                HStack(spacing: 16) {
                    Button("Export WAV", action: onExport)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.cyan)

                    Button("Play", action: onPlay)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.cyan)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
