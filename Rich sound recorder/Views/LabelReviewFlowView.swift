import AVFoundation
import SwiftUI

struct LabelReviewFlowView: View {
    private enum FailureContext: Equatable {
        case loadingSnippet
        case applyingDeletions
    }

    private enum Stage: Equatable {
        case intro
        case loading
        case playing
        case decided(RSRReviewOutcome)
        case finalizing
        case finished
        case failed(FailureContext, String)
    }

    let labelUID: String
    let labelName: String
    let snippets: [LabelSnippet]
    let clipRepository: ClipRepository

    @Environment(\.dismiss) private var dismiss

    @State private var stage: Stage = .intro
    @State private var currentIndex = 0
    @State private var keptCount = 0
    @State private var removedCount = 0
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var downloadProgress = 0.12
    @State private var isSubmittingDecision = false
    @State private var deletedSnippets: [DeletedSnippetRange] = []
    @State private var deletedSnippetCount = 0

    @State private var audioPlayer: AVAudioPlayer?
    @State private var playbackTimer: Timer?
    @State private var loadTask: Task<Void, Never>?
    @State private var downloadProgressTask: Task<Void, Never>?
    @State private var advanceTask: Task<Void, Never>?
    @State private var lastDecision: ClipReviewDecision?

    var body: some View {
        ZStack {
            RSR.canvas.ignoresSafeArea()

            switch stage {
            case .intro:
                introView
            case .loading:
                reviewScaffold {
                    loadingContent
                } footer: {
                    footerDecisionBar(enabled: false)
                }
            case .playing:
                reviewScaffold {
                    playingContent
                } footer: {
                    footerDecisionBar(enabled: !isSubmittingDecision)
                }
            case .decided(let outcome):
                reviewScaffold {
                    decidedContent(outcome)
                } footer: {
                    decidedFooter
                }
            case .finalizing:
                reviewScaffold {
                    finalizingContent
                } footer: {
                    VStack(spacing: 12) {
                        ProgressView()
                        statsLabel
                    }
                }
            case .finished:
                finishedView
            case .failed(let context, let message):
                reviewScaffold {
                    failedContent(context: context, message: message)
                } footer: {
                    VStack(spacing: 12) {
                        RSRPrimaryButton(title: "Retry") {
                            retry(for: context)
                        }
                        statsLabel
                    }
                }
            }
        }
        .onDisappear {
            tearDownPlayback()
            cancelBackgroundWork()
        }
    }

    private func reviewScaffold<Content: View, Footer: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        VStack(spacing: 0) {
            topBar

            if stage != .intro && stage != .finished {
                RSRReviewProgressHeader(index: currentIndex + 1, total: snippets.count)
                    .padding(.horizontal, RSRSpace.screen)
                    .padding(.top, 10)
            }

            Spacer(minLength: 0)
            content()
            Spacer(minLength: 0)
        }
        .safeAreaInset(edge: .bottom) {
            footer()
                .padding(.horizontal, RSRSpace.screen)
                .padding(.top, 10)
                .padding(.bottom, 20)
                .background(.clear)
        }
    }

    private var topBar: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .font(.rsrHeadline)
            .foregroundStyle(RSR.accent)
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 7) {
                Circle()
                    .fill(RSR.success)
                    .frame(width: 7, height: 7)
                Text(labelName)
                    .font(.rsrBody.weight(.semibold))
                    .foregroundStyle(RSR.labelSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, RSRSpace.screen)
        .padding(.top, 4)
    }

    private var introView: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            RSRHeadphonesPrompt(
                count: snippets.count,
                totalLength: totalDurationLabel
            )
            .padding(.horizontal, 40)
            Spacer()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                RSRPrimaryButton(title: "Start reviewing") {
                    currentIndex = 0
                    keptCount = 0
                    removedCount = 0
                    deletedSnippets = []
                    deletedSnippetCount = 0
                    loadCurrentSnippet()
                }

                Text("Best with headphones in a quiet space")
                    .font(.rsrCaption)
                    .foregroundStyle(RSR.labelTertiary)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
    }

    private var loadingContent: some View {
        VStack(spacing: 0) {
            RSRDownloadRing(progress: downloadProgress)
                .padding(.bottom, 30)

            Text("DOWNLOADING")
                .rsrEyebrow()
                .padding(.bottom, 11)

            Text("Loading recording")
                .font(.rsrTitle)
                .foregroundStyle(RSR.labelPrimary)

            clipMetadataLine(for: currentSnippet)
                .padding(.top, 13)

            RSRWaveform(amplitude: 78, seed: waveformSeed, color: RSR.trackFill)
                .frame(height: 84)
                .opacity(0.6)
                .padding(.top, 30)

            Text("Plays automatically when ready")
                .font(.rsrSubhead)
                .foregroundStyle(RSR.labelTertiary)
                .padding(.top, 22)
        }
        .padding(.horizontal, RSRSpace.screen)
    }

    private var playingContent: some View {
        VStack(spacing: 0) {
            Text(recordedAtLabel(for: currentSnippet))
                .font(.rsrSubhead)
                .foregroundStyle(RSR.labelSecondary)
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .rsrGlass(.thin, radius: 14, elevation: .resting)

            HStack(alignment: .bottom, spacing: 10) {
                Text(timeLabel(for: currentTime))
                    .rsrDisplayFont()
                    .foregroundStyle(RSR.labelPrimary)
                    .monospacedDigit()

                Text("/ \(timeLabel(for: duration))")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(RSR.labelTertiary)
                    .padding(.bottom, 12)
            }
            .padding(.top, 24)

            HStack(spacing: 7) {
                HStack(alignment: .bottom, spacing: 2) {
                    playingBar(6)
                    playingBar(12)
                    playingBar(8)
                }
                .frame(height: 12)

                Text(audioPlayer?.isPlaying == true ? "PLAYING" : "READY")
                    .font(.rsrCaption)
                    .tracking(0.6)
                    .foregroundStyle(RSR.accent.opacity(0.85))
            }
            .padding(.top, 13)

            RSRReviewWaveform(
                seed: waveformSeed,
                progress: playbackFraction
            )
            .frame(height: 150)
            .padding(.top, 20)

            HStack {
                Text(timeLabel(for: currentTime))
                    .font(.rsrCaption)
                    .foregroundStyle(RSR.labelSecondary)
                    .monospacedDigit()
                Spacer()
                Text(timeLabel(for: duration))
                    .font(.rsrCaption)
                    .foregroundStyle(RSR.labelTertiary)
                    .monospacedDigit()
            }
            .padding(.top, 4)

            RSRReplayButton {
                replay()
            }
            .padding(.top, 24)
        }
        .padding(.horizontal, RSRSpace.screen)
    }

    private func decidedContent(_ outcome: RSRReviewOutcome) -> some View {
        VStack(spacing: 0) {
            RSROutcomeBadge(outcome: outcome)

            Text(outcome.title)
                .font(.rsrLargeTitle)
                .foregroundStyle(outcome.tint)
                .padding(.top, 26)

            Text(outcome == .kept ? "Saved to \(labelName) dataset" : "Won’t be used to train \(labelName)")
                .font(.rsrBody)
                .foregroundStyle(RSR.labelSecondary)
                .padding(.top, 8)

            if let nextSnippet {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading next · \(summaryLabel(for: nextSnippet))")
                        .font(.rsrSubhead)
                        .foregroundStyle(RSR.labelSecondary)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .rsrGlass(.thin, radius: 16, elevation: .resting)
                .padding(.top, 34)
            } else {
                Text("Final recording in this review")
                    .font(.rsrSubhead)
                    .foregroundStyle(RSR.labelSecondary)
                    .padding(.top, 34)
            }
        }
        .padding(.horizontal, RSRSpace.screen)
    }

    private func failedContent(context: FailureContext, message: String) -> some View {
        VStack(alignment: .leading, spacing: RSRSpace.lg) {
            RSROutcomeBadge(outcome: .removed)

            VStack(alignment: .leading, spacing: RSRSpace.sm) {
                Text(context == .loadingSnippet ? "Couldn’t load recording" : "Couldn’t delete discarded recordings")
                    .font(.rsrTitle)
                    .foregroundStyle(RSR.labelPrimary)

                Text(message)
                    .font(.rsrBody)
                    .foregroundStyle(RSR.labelSecondary)
            }
        }
        .padding(.horizontal, RSRSpace.screen)
    }

    private var finalizingContent: some View {
        VStack(spacing: 0) {
            ProgressView()
                .controlSize(.large)
                .padding(.bottom, 30)

            Text("APPLYING CHANGES")
                .rsrEyebrow()
                .padding(.bottom, 11)

            Text("Deleting discarded recordings")
                .font(.rsrTitle)
                .foregroundStyle(RSR.labelPrimary)

            Text("Removed \(removedCount) clip\(removedCount == 1 ? "" : "s") from \(labelName)")
                .font(.rsrBody)
                .foregroundStyle(RSR.labelSecondary)
                .padding(.top, 8)
        }
        .padding(.horizontal, RSRSpace.screen)
    }

    private var finishedView: some View {
        let removedSummary = deletedSnippetCount > 0 ? deletedSnippetCount : removedCount

        return VStack(spacing: 0) {
            topBar
            Spacer()
            RSROutcomeBadge(outcome: .kept)
            Text("Review complete")
                .font(.rsrLargeTitle)
                .foregroundStyle(RSR.labelPrimary)
                .padding(.top, 26)
            Text("\(keptCount) kept · \(removedSummary) removed")
                .font(.rsrBody)
                .foregroundStyle(RSR.labelSecondary)
                .padding(.top, 8)
            Spacer()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                RSRPrimaryButton(title: "Done") {
                    dismiss()
                }
                statsLabel
            }
            .padding(.horizontal, RSRSpace.screen)
            .padding(.bottom, 20)
        }
    }

    private func footerDecisionBar(enabled: Bool) -> some View {
        VStack(spacing: 12) {
            RSRDecisionBar(
                onDiscard: { submitDecision(.discard) },
                onKeep: { submitDecision(.keep) }
            )
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.4)
            statsLabel
        }
    }

    private var decidedFooter: some View {
        VStack(spacing: 12) {
            Button {
                undoDecision()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Undo")
                        .font(.rsrBody.weight(.semibold))
                }
                .foregroundStyle(RSR.accent)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .rsrGlass(.thin, radius: 15, elevation: .resting)
            }
            .buttonStyle(.plain)

            statsLabel
        }
    }

    private var statsLabel: some View {
        Text("Kept \(keptCount) · Removed \(removedCount)")
            .font(.rsrCaption)
            .foregroundStyle(RSR.labelTertiary)
            .monospacedDigit()
    }

    private var currentSnippet: LabelSnippet? {
        guard snippets.indices.contains(currentIndex) else { return nil }
        return snippets[currentIndex]
    }

    private var nextSnippet: LabelSnippet? {
        let nextIndex = currentIndex + 1
        guard snippets.indices.contains(nextIndex) else { return nil }
        return snippets[nextIndex]
    }

    private var playbackFraction: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    private var waveformSeed: Double {
        Double((currentSnippet?.start ?? 0).rounded(.down).truncatingRemainder(dividingBy: 97))
    }

    private var totalDurationLabel: String {
        let totalSeconds = snippets.reduce(0) { $0 + $1.duration }
        if totalSeconds >= 60 {
            return "~\(Int((totalSeconds / 60).rounded(.up))) min total"
        }
        return "~\(Int(totalSeconds.rounded())) sec total"
    }

    private func playingBar(_ height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(RSR.accent)
            .frame(width: 3, height: height)
    }

    private func clipMetadataLine(for snippet: LabelSnippet?) -> some View {
        HStack(spacing: 8) {
            Text(recordedAtLabel(for: snippet))
                .font(.rsrSubhead)
                .foregroundStyle(RSR.labelSecondary)
            Circle()
                .fill(RSR.labelTertiary)
                .frame(width: 3, height: 3)
            Text(durationLabel(for: snippet))
                .font(.rsrSubhead.weight(.semibold))
                .foregroundStyle(RSR.labelSecondary)
                .monospacedDigit()
        }
    }

    private func recordedAtLabel(for snippet: LabelSnippet?) -> String {
        guard let snippet else { return "Recorded clip" }
        return "Recorded \(snippet.startDate.formatted(date: .abbreviated, time: .shortened))"
    }

    private func durationLabel(for snippet: LabelSnippet?) -> String {
        guard let snippet else { return "--:--" }
        return timeLabel(for: snippet.duration)
    }

    private func summaryLabel(for snippet: LabelSnippet) -> String {
        "\(snippet.startDate.formatted(date: .abbreviated, time: .omitted)) · \(timeLabel(for: snippet.duration))"
    }

    private func loadCurrentSnippet() {
        guard let snippet = currentSnippet else {
            stage = .finished
            return
        }

        cancelBackgroundWork()
        tearDownPlayback()

        downloadProgress = 0.12
        stage = .loading

        startDownloadProgressAnimation()

        loadTask = Task {
            do {
                let audioFile = try await clipRepository.downloadSnippet(start: snippet.start, end: snippet.end)
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    downloadProgressTask?.cancel()
                    downloadProgress = 1
                    preparePlayer(with: audioFile)
                }
            } catch {
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    downloadProgressTask?.cancel()
                    stage = .failed(.loadingSnippet, error.localizedDescription)
                }
            }
        }
    }

    private func preparePlayer(with audioFile: SnippetAudioFile) {
        do {
            let player = try AVAudioPlayer(contentsOf: audioFile.fileURL)
            player.prepareToPlay()
            audioPlayer = player
            duration = player.duration
            currentTime = 0
            stage = .playing
            startPlaybackTimer()
            replay()
        } catch {
            stage = .failed(.loadingSnippet, error.localizedDescription)
        }
    }

    private func replay() {
        guard let audioPlayer else { return }
        audioPlayer.currentTime = 0
        currentTime = 0
        audioPlayer.play()
    }

    private func submitDecision(_ decision: ClipReviewDecision) {
        guard let snippet = currentSnippet, !isSubmittingDecision else { return }

        isSubmittingDecision = true

        isSubmittingDecision = false
        lastDecision = decision
        switch decision {
        case .keep:
            keptCount += 1
            stage = .decided(.kept)
        case .discard:
            deletedSnippets.append(
                DeletedSnippetRange(start: snippet.start, end: snippet.end)
            )
            removedCount += 1
            stage = .decided(.removed)
        }
        tearDownPlayback()
        scheduleAdvance()
    }

    private func scheduleAdvance() {
        advanceTask?.cancel()
        advanceTask = Task {
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                moveToNextSnippet()
            }
        }
    }

    private func undoDecision() {
        advanceTask?.cancel()
        switch lastDecision {
        case .keep:
            keptCount = max(0, keptCount - 1)
        case .discard:
            removedCount = max(0, removedCount - 1)
            if let snippet = currentSnippet {
                let matchingIndex = deletedSnippets.lastIndex { candidate in
                    candidate.start == snippet.start && candidate.end == snippet.end
                }
                if let matchingIndex {
                    deletedSnippets.remove(at: matchingIndex)
                }
            }
        case .none:
            break
        }
        lastDecision = nil
        stage = .playing
        startPlaybackTimer()
        replay()
    }

    private func moveToNextSnippet() {
        lastDecision = nil
        if currentIndex + 1 < snippets.count {
            currentIndex += 1
            loadCurrentSnippet()
        } else {
            finalizeReview()
        }
    }

    private func finalizeReview() {
        guard !deletedSnippets.isEmpty else {
            stage = .finished
            return
        }

        tearDownPlayback()
        cancelBackgroundWork()
        stage = .finalizing

        Task {
            do {
                let deletedCount = try await clipRepository.deleteSnippets(
                    labelUID: labelUID,
                    snippets: deletedSnippets
                )

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    deletedSnippetCount = deletedCount
                    stage = .finished
                }
            } catch {
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    stage = .failed(.applyingDeletions, error.localizedDescription)
                }
            }
        }
    }

    private func retry(for context: FailureContext) {
        switch context {
        case .loadingSnippet:
            loadCurrentSnippet()
        case .applyingDeletions:
            finalizeReview()
        }
    }

    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            guard let audioPlayer else { return }
            currentTime = audioPlayer.currentTime
        }
        RunLoop.main.add(timer, forMode: .common)
        playbackTimer = timer
    }

    private func tearDownPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        audioPlayer?.stop()
        audioPlayer = nil
        currentTime = 0
        duration = 0
    }

    private func startDownloadProgressAnimation() {
        downloadProgressTask?.cancel()
        downloadProgressTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    downloadProgress = min(downloadProgress + 0.06, 0.9)
                }
            }
        }
    }

    private func cancelBackgroundWork() {
        loadTask?.cancel()
        loadTask = nil
        downloadProgressTask?.cancel()
        downloadProgressTask = nil
        advanceTask?.cancel()
        advanceTask = nil
    }

    private func timeLabel(for seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "--:--" }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: seconds) ?? "--:--"
    }
}
