import SwiftUI

struct LabelDetailView: View {
    let labelUID: String
    let labelName: String
    let clipRepository: ClipRepository

    @State private var snippets: [LabelSnippet] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(labelName)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)

                    Text("UID: \(labelUID)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.white.opacity(0.06))

            Section("Clips") {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(.cyan)
                        Spacer()
                    }
                } else if let errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Failed to load clips")
                            .font(.subheadline.weight(.semibold))
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            Task { await loadSnippets() }
                        }
                        .foregroundStyle(.cyan)
                    }
                } else if snippets.isEmpty {
                    Text("No clips found for this label")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snippets) { snippet in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(clipRangeLabel(for: snippet))
                                .font(.subheadline.weight(.medium))

                            Text("Duration: \(formattedDuration(snippet.duration))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .listRowBackground(Color.white.opacity(0.06))
        }
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(labelName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await loadSnippets()
        }
        .refreshable {
            await loadSnippets()
        }
    }

    private func loadSnippets() async {
        isLoading = true
        errorMessage = nil

        do {
            snippets = try await clipRepository.listSnippets(labelUID: labelUID)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func clipRangeLabel(for snippet: LabelSnippet) -> String {
        let start = Date(timeIntervalSince1970: snippet.start)
        let end = Date(timeIntervalSince1970: snippet.end)
        let startText = start.formatted(date: .abbreviated, time: .shortened)
        let endText = end.formatted(date: .omitted, time: .shortened)
        return "\(startText) – \(endText)"
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 60 ? [.minute, .second] : [.second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? String(format: "%.1fs", duration)
    }
}
