import SwiftUI

struct LabelDetailView: View {
    let labelUID: String
    let labelName: String
    let clipRepository: ClipRepository

    @State private var snippets: [LabelSnippet] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showReviewFlow = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RSRSpace.lg) {
                headerSection
                labelSummaryCard
                recordingsSection
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
        .safeAreaInset(edge: .bottom) {
            if !isLoading && errorMessage == nil && !snippets.isEmpty {
                RSRPrimaryButton(title: "Review one by one") {
                    showReviewFlow = true
                }
                .padding(.horizontal, RSRSpace.screen)
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
        }
        .fullScreenCover(isPresented: $showReviewFlow, onDismiss: {
            Task { await loadSnippets() }
        }) {
            LabelReviewFlowView(
                labelUID: labelUID,
                labelName: labelName,
                snippets: snippets,
                clipRepository: clipRepository
            )
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: RSRSpace.xs) {
            Text(labelName)
                .font(.rsrLargeTitle)
                .tracking(RSRTracking.largeTitle)
                .foregroundStyle(RSR.labelPrimary)

            Text("Review recordings for this label and trim the training set.")
                .font(.rsrSubhead)
                .foregroundStyle(RSR.labelSecondary)
        }
    }

    private var labelSummaryCard: some View {
        RSRCard(radius: RSRRadius.card) {
            VStack(alignment: .leading, spacing: RSRSpace.md) {
                detailRow(title: "Label", value: labelName)
                detailRow(title: "UID", value: labelUID, selectable: true)
                detailRow(title: "Recordings", value: isLoading ? "Loading..." : "\(snippets.count)")
                detailRow(title: "Queued review time", value: isLoading ? "Loading..." : totalDurationLabel)
            }
        }
    }

    private var recordingsSection: some View {
        VStack(alignment: .leading, spacing: RSRSpace.md) {
            sectionTitle("Recordings")

            if isLoading {
                loadingCard("Loading recordings...")
            } else if let errorMessage {
                messageCard(
                    title: "Couldn’t load recordings",
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
                    title: "No recordings yet",
                    subtitle: "This label doesn’t have any recordings ready for review yet.",
                    systemImage: "waveform.slash",
                    tint: RSR.labelSecondary
                )
            } else {
                VStack(alignment: .leading, spacing: RSRSpace.md) {
                    reviewCard

                    RSRCard(radius: RSRRadius.card) {
                        VStack(spacing: 0) {
                            ForEach(Array(snippets.prefix(6).enumerated()), id: \.element.id) { index, snippet in
                                ReviewRecordingRow(
                                    timestamp: snippet.startDate.formatted(date: .abbreviated, time: .shortened),
                                    relative: snippet.relativeTimeLabel,
                                    duration: formattedDuration(snippet.duration)
                                )
                                if index < min(snippets.count, 6) - 1 {
                                    Divider()
                                        .overlay(RSR.hairline)
                                        .padding(.leading, 51)
                                }
                            }
                        }
                    }

                    if snippets.count > 6 {
                        Text("+ \(snippets.count - 6) more recordings")
                            .font(.rsrSubhead)
                            .foregroundStyle(RSR.labelTertiary)
                            .frame(maxWidth: .infinity)
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

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 60 ? [.minute, .second] : [.second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? String(format: "%.1fs", duration)
    }

    private var totalDurationLabel: String {
        let total = snippets.reduce(0) { $0 + $1.duration }
        guard total > 0 else { return "0 sec" }
        if total >= 60 {
            return "\(Int((total / 60).rounded(.up))) min"
        }
        return "\(Int(total.rounded())) sec"
    }
    
    private var reviewCard: some View {
        RSRCard(radius: RSRRadius.card) {
            VStack(alignment: .leading, spacing: RSRSpace.md) {
                Text("Ready to review")
                    .font(.rsrTitle)
                    .tracking(RSRTracking.title)
                    .foregroundStyle(RSR.labelPrimary)

                Text("\(snippets.count) recordings · \(totalDurationLabel) queued")
                    .font(.rsrSubhead)
                    .foregroundStyle(RSR.labelSecondary)

                Divider()
                    .overlay(RSR.hairline)

                Text("Listen through each recording and keep or discard it before training.")
                    .font(.rsrBody)
                    .foregroundStyle(RSR.labelSecondary)
            }
        }
    }
}

private struct ReviewRecordingRow: View {
    let timestamp: String
    let relative: String
    let duration: String

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(RSR.accentTint)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "waveform")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(RSR.accent)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(timestamp)
                    .font(.rsrBody.weight(.semibold))
                    .foregroundStyle(RSR.labelPrimary)

                Text(relative)
                    .font(.rsrSubhead)
                    .foregroundStyle(RSR.labelSecondary)
            }

            Spacer()

            Text(duration)
                .font(.rsrSubhead.weight(.semibold))
                .foregroundStyle(RSR.labelSecondary)
                .monospacedDigit()
        }
        .frame(minHeight: 44)
    }
}

private extension LabelSnippet {
    var relativeTimeLabel: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: startDate, relativeTo: Date())
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
