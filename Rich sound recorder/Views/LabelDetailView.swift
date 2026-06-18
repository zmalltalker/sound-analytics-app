import SwiftUI

struct LabelDetailView: View {
    let labelUID: String
    let labelName: String
    let clipRepository: ClipRepository

    @State private var snippets: [LabelSnippet] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var downloadStates: [LabelSnippet.ID: SnippetDownloadState] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RSRSpace.lg) {
                headerSection
                labelSummaryCard
                clipsSection
            }
            .padding(.horizontal, RSRSpace.screen)
            .padding(.top, RSRSpace.card)
            .padding(.bottom, 120)
        }
        .background(RSR.canvas.ignoresSafeArea())
        .navigationTitle(labelName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadSnippets()
        }
        .refreshable {
            await loadSnippets()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: RSRSpace.xs) {
            Text(labelName)
                .font(.rsrLargeTitle)
                .tracking(RSRTracking.largeTitle)
                .foregroundStyle(RSR.labelPrimary)

            Text("Recorded clips and downloads for this label.")
                .font(.rsrSubhead)
                .foregroundStyle(RSR.labelSecondary)
        }
    }

    private var labelSummaryCard: some View {
        RSRCard(radius: RSRRadius.card) {
            VStack(alignment: .leading, spacing: RSRSpace.md) {
                detailRow(title: "Label", value: labelName)
                detailRow(title: "UID", value: labelUID, selectable: true)
                detailRow(title: "Clips", value: isLoading ? "Loading..." : "\(snippets.count)")
            }
        }
    }

    private var clipsSection: some View {
        VStack(alignment: .leading, spacing: RSRSpace.md) {
            sectionTitle("Clips")

            if isLoading {
                loadingCard("Loading clips...")
            } else if let errorMessage {
                messageCard(
                    title: "Couldn’t load clips",
                    subtitle: errorMessage,
                    systemImage: "exclamationmark.triangle.fill",
                    tint: RSR.warning
                ) {
                    Button("Retry") {
                        Task { await loadSnippets() }
                    }
                    .font(.rsrSubhead.weight(.semibold))
                    .foregroundStyle(RSR.accent)
                }
            } else if snippets.isEmpty {
                messageCard(
                    title: "No clips yet",
                    subtitle: "This label doesn’t have any downloadable snippets yet.",
                    systemImage: "waveform.slash",
                    tint: RSR.labelSecondary
                )
            } else {
                VStack(spacing: RSRSpace.sm) {
                    ForEach(snippets) { snippet in
                        SnippetRow(
                            snippet: snippet,
                            state: downloadStates[snippet.id] ?? .idle,
                            labelName: labelName,
                            clipRangeLabel: clipRangeLabel(for: snippet),
                            durationLabel: formattedDuration(snippet.duration),
                            onDownload: { downloadSnippet(snippet) }
                        )
                    }
                }
            }
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

    private func downloadSnippet(_ snippet: LabelSnippet) {
        downloadStates[snippet.id] = .downloading

        Task {
            do {
                let result = try await clipRepository.downloadSnippet(start: snippet.start, end: snippet.end)
                await MainActor.run {
                    downloadStates[snippet.id] = .downloaded(result)
                }
            } catch {
                await MainActor.run {
                    downloadStates[snippet.id] = .failed(error.localizedDescription)
                }
            }
        }
    }
}

private struct SnippetRow: View {
    let snippet: LabelSnippet
    let state: SnippetDownloadState
    let labelName: String
    let clipRangeLabel: String
    let durationLabel: String
    let onDownload: () -> Void

    var body: some View {
        RSRCard(radius: RSRRadius.control) {
            VStack(alignment: .leading, spacing: RSRSpace.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(clipRangeLabel)
                        .font(.rsrBody.weight(.semibold))
                        .foregroundStyle(RSR.labelPrimary)

                    Text("Duration · \(durationLabel)")
                        .font(.rsrMeta)
                        .foregroundStyle(RSR.labelSecondary)
                }

                HStack(alignment: .center, spacing: 12) {
                    Circle()
                        .fill(statusColor.opacity(0.16))
                        .frame(width: 34, height: 34)
                        .overlay {
                            Image(systemName: statusIcon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(statusColor)
                        }

                    Text(statusLabel)
                        .font(.rsrSubhead.weight(.semibold))
                        .foregroundStyle(RSR.labelSecondary)

                    Spacer()

                    actionView
                }

                if case .failed(let message) = state {
                    Text(message)
                        .font(.rsrSubhead)
                        .foregroundStyle(RSR.warning)
                }
            }
        }
    }

    @ViewBuilder
    private var actionView: some View {
        switch state {
        case .idle:
            Button("Download", action: onDownload)
                .font(.rsrSubhead.weight(.semibold))
                .foregroundStyle(RSR.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RSR.accentTint)
                .clipShape(RoundedRectangle(cornerRadius: RSRRadius.chip, style: .continuous))

        case .downloading:
            ProgressView()
                .tint(RSR.accent)

        case .downloaded(let audioFile):
            NavigationLink {
                SnippetPlayerView(
                    labelName: labelName,
                    audioFile: audioFile
                )
            } label: {
                Text("Open")
                    .font(.rsrSubhead.weight(.semibold))
                    .foregroundStyle(RSR.success)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RSR.success.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: RSRRadius.chip, style: .continuous))
            }
            .buttonStyle(.plain)

        case .failed:
            Button("Retry", action: onDownload)
                .font(.rsrSubhead.weight(.semibold))
                .foregroundStyle(RSR.warning)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RSR.warning.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: RSRRadius.chip, style: .continuous))
        }
    }

    private var statusLabel: String {
        switch state {
        case .idle:
            return "Ready to download"
        case .downloading:
            return "Downloading clip..."
        case .downloaded:
            return "Downloaded"
        case .failed:
            return "Download failed"
        }
    }

    private var statusIcon: String {
        switch state {
        case .idle:
            return "arrow.down"
        case .downloading:
            return "arrow.trianglehead.2.clockwise"
        case .downloaded:
            return "checkmark"
        case .failed:
            return "exclamationmark"
        }
    }

    private var statusColor: Color {
        switch state {
        case .idle, .downloading:
            return RSR.accent
        case .downloaded:
            return RSR.success
        case .failed:
            return RSR.warning
        }
    }
}

private func detailRow(title: String, value: String, selectable: Bool = false) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title)
            .font(.rsrCaption)
            .tracking(RSRTracking.eyebrow)
            .foregroundStyle(RSR.labelSecondary)
            .textCase(.uppercase)

        if selectable {
            Text(value)
                .font(.rsrBody.weight(.semibold))
                .foregroundStyle(RSR.labelPrimary)
                .textSelection(.enabled)
        } else {
            Text(value)
                .font(.rsrBody.weight(.semibold))
                .foregroundStyle(RSR.labelPrimary)
        }
    }
}

private func sectionTitle(_ title: String) -> some View {
    Text(title)
        .font(.rsrCaption)
        .tracking(RSRTracking.eyebrow)
        .foregroundStyle(RSR.labelSecondary)
        .textCase(.uppercase)
}

private func loadingCard(_ title: String) -> some View {
    RSRCard(radius: RSRRadius.card) {
        HStack(spacing: RSRSpace.md) {
            ProgressView()
                .tint(RSR.accent)
            Text(title)
                .font(.rsrBody.weight(.semibold))
                .foregroundStyle(RSR.labelPrimary)
        }
    }
}

private func messageCard<Accessory: View>(
    title: String,
    subtitle: String,
    systemImage: String,
    tint: Color,
    @ViewBuilder accessory: () -> Accessory
) -> some View {
    RSRCard(radius: RSRRadius.card) {
        VStack(alignment: .leading, spacing: RSRSpace.md) {
            HStack(spacing: 14) {
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(tint)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.rsrHeadline)
                        .foregroundStyle(RSR.labelPrimary)

                    Text(subtitle)
                        .font(.rsrSubhead)
                        .foregroundStyle(RSR.labelSecondary)
                }
            }

            accessory()
        }
    }
}

private func messageCard(
    title: String,
    subtitle: String,
    systemImage: String,
    tint: Color
) -> some View {
    messageCard(
        title: title,
        subtitle: subtitle,
        systemImage: systemImage,
        tint: tint
    ) {
        EmptyView()
    }
}

private enum SnippetDownloadState {
    case idle
    case downloading
    case downloaded(SnippetAudioFile)
    case failed(String)
}
