//
//  ReviewLabelView.swift
//  Rich Sound Recorder — Design System · Example
//
//  Reference assembly of the "Review labeled recordings" flow, built
//  entirely from RSR widgets + RSRReview* widgets. One screen, four
//  in-session phases (loading → playing → decided), plus the queue
//  entry and the headphones pre-flight as their own composable views.
//
//  Flow: a label is selected → its recordings list (ReviewQueueView) →
//  "Review one by one" → headphones prompt (HeadphonesIntroView) →
//  for each recording: download, auto-play, replay / keep / discard,
//  brief confirmation, advance. Empty queue → ReviewEmptyView.
//

import SwiftUI

// MARK: - Sample model

struct ReviewClip: Identifiable {
    let id = UUID()
    let timestamp: String   // "Jun 13 · 4:47 PM"
    let relative: String    // "Yesterday"
    let duration: String    // "0:21"
    let seconds: Int
}

extension ReviewClip {
    static let sample: [ReviewClip] = [
        .init(timestamp: "Jun 14 · 2:31 PM",  relative: "Recorded today", duration: "0:14", seconds: 14),
        .init(timestamp: "Jun 14 · 11:02 AM", relative: "Recorded today", duration: "0:09", seconds: 9),
        .init(timestamp: "Jun 13 · 4:47 PM",  relative: "Yesterday",      duration: "0:21", seconds: 21),
        .init(timestamp: "Jun 12 · 9:15 AM",  relative: "2 days ago",     duration: "0:12", seconds: 12),
        .init(timestamp: "Jun 11 · 6:30 PM",  relative: "3 days ago",     duration: "0:18", seconds: 18),
        .init(timestamp: "Jun 10 · 1:54 PM",  relative: "4 days ago",     duration: "0:11", seconds: 11),
    ]
}

// MARK: - In-session review screen

struct ReviewLabelView: View {
    enum Phase: Equatable { case loading, playing, decided(RSRReviewOutcome) }

    let label: String
    let index: Int        // 1-based position in the queue
    let total: Int
    let clip: ReviewClip
    @State var phase: Phase

    init(label: String = "Bearing fault", index: Int = 3, total: Int = 24,
         clip: ReviewClip = ReviewClip.sample[2], phase: Phase = .playing) {
        self.label = label; self.index = index; self.total = total
        self.clip = clip; self._phase = State(initialValue: phase)
    }

    var body: some View {
        ZStack {
            RSR.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                RSRReviewProgressHeader(index: index, total: total)
                    .padding(.horizontal, RSRSpace.screen)
                    .padding(.top, 10)

                Spacer(minLength: 0)
                content
                Spacer(minLength: 0)

                footer
            }
        }
    }

    // Top bar: Cancel + label chip (with readiness dot)
    private var navBar: some View {
        HStack {
            Button("Cancel") {}.font(.rsrHeadline).foregroundStyle(RSR.accent).buttonStyle(.plain)
            Spacer()
            HStack(spacing: 7) {
                Circle().fill(RSR.success).frame(width: 7, height: 7)
                Text(label).font(.rsrBody.weight(.semibold)).foregroundStyle(RSR.labelSecondary)
            }
        }
        .padding(.horizontal, RSRSpace.screen)
        .padding(.top, 4)
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:           loadingContent
        case .playing:           playingContent
        case .decided(let out):  decidedContent(out)
        }
    }

    // Loading / downloading
    private var loadingContent: some View {
        VStack(spacing: 0) {
            RSRDownloadRing(progress: 0.38).padding(.bottom, 30)
            Text("DOWNLOADING").rsrEyebrow().padding(.bottom, 11)
            Text("Loading recording").font(.rsrTitle).foregroundStyle(RSR.labelPrimary)
            HStack(spacing: 8) {
                Text("Recorded \(clip.timestamp)").font(.rsrSubhead).foregroundStyle(RSR.labelSecondary)
                Circle().fill(RSR.labelTertiary).frame(width: 3, height: 3)
                Text(clip.duration).font(.rsrSubhead.weight(.semibold)).foregroundStyle(RSR.labelSecondary).monospacedDigit()
            }
            .padding(.top, 13)
            RSRWaveform(amplitude: 78, seed: 9, color: RSR.trackFill)
                .frame(height: 84).opacity(0.6).padding(.top, 30)
            Text("Plays automatically when ready")
                .font(.rsrSubhead).foregroundStyle(RSR.labelTertiary).padding(.top, 22)
        }
        .padding(.horizontal, RSRSpace.screen)
    }

    // Playing — the hero
    private var playingContent: some View {
        VStack(spacing: 0) {
            Text("Recorded \(clip.timestamp)")
                .font(.rsrSubhead).foregroundStyle(RSR.labelSecondary)
                .padding(.horizontal, 15).padding(.vertical, 8)
                .rsrGlass(.thin, radius: 14, elevation: .resting)

            HStack(alignment: .bottom, spacing: 10) {
                Text("0:13").font(.rsrDisplay).foregroundStyle(RSR.labelPrimary).monospacedDigit()
                Text("/ \(clip.duration)").font(.system(size: 19, weight: .medium))
                    .foregroundStyle(RSR.labelTertiary).padding(.bottom, 12)
            }
            .padding(.top, 24)

            HStack(spacing: 7) {
                HStack(alignment: .bottom, spacing: 2) {
                    bar(6); bar(12); bar(8)
                }.frame(height: 12)
                Text("PLAYING").font(.rsrCaption).tracking(0.6)
                    .foregroundStyle(RSR.accent.opacity(0.85))
            }
            .padding(.top, 13)

            RSRReviewWaveform(progress: 0.62)
                .frame(height: 150).padding(.top, 20)

            HStack {
                Text("0:13").font(.rsrCaption).foregroundStyle(RSR.labelSecondary).monospacedDigit()
                Spacer()
                Text(clip.duration).font(.rsrCaption).foregroundStyle(RSR.labelTertiary).monospacedDigit()
            }
            .padding(.top, 4)

            RSRReplayButton().padding(.top, 24)
        }
        .padding(.horizontal, RSRSpace.screen)
    }

    private func bar(_ h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1).fill(RSR.accent).frame(width: 3, height: h)
    }

    // Just decided
    private func decidedContent(_ out: RSRReviewOutcome) -> some View {
        VStack(spacing: 0) {
            RSROutcomeBadge(outcome: out)
            Text(out.title).font(.rsrLargeTitle).foregroundStyle(out.tint).padding(.top, 26)
            Text(out == .kept ? "Saved to \(label) dataset" : "Won’t be used to train \(label)")
                .font(.rsrBody).foregroundStyle(RSR.labelSecondary).padding(.top, 8)
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Loading next · Jun 12 · 0:12").font(.rsrSubhead).foregroundStyle(RSR.labelSecondary)
            }
            .padding(.horizontal, 18).padding(.vertical, 11)
            .rsrGlass(.thin, radius: 16, elevation: .resting)
            .padding(.top, 34)
        }
        .padding(.horizontal, RSRSpace.screen)
    }

    // Footer changes per phase
    @ViewBuilder private var footer: some View {
        switch phase {
        case .playing:
            VStack(spacing: 12) {
                RSRDecisionBar(
                    onDiscard: { phase = .decided(.removed) },
                    onKeep: { phase = .decided(.kept) })
                Text("Kept 2 · Removed 0").font(.rsrCaption).foregroundStyle(RSR.labelTertiary).monospacedDigit()
            }
            .padding(.horizontal, RSRSpace.screen).padding(.bottom, 30)
        case .loading:
            RSRDecisionBar().disabled(true).opacity(0.4)
                .padding(.horizontal, RSRSpace.screen).padding(.bottom, 30)
        case .decided:
            VStack(spacing: 12) {
                Button {} label: {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.uturn.backward").font(.system(size: 14, weight: .semibold))
                        Text("Undo").font(.rsrBody.weight(.semibold))
                    }
                    .foregroundStyle(RSR.accent)
                    .padding(.horizontal, 22).padding(.vertical, 10)
                    .rsrGlass(.thin, radius: 15, elevation: .resting)
                }.buttonStyle(.plain)
                Text("Kept 3 · Removed 0").font(.rsrCaption).foregroundStyle(RSR.labelTertiary).monospacedDigit()
            }
            .padding(.bottom, 30)
        }
    }
}

// MARK: - Queue entry (label detail)

struct ReviewQueueView: View {
    let label = "Bearing fault"
    let clips = ReviewClip.sample

    var body: some View {
        ZStack(alignment: .bottom) {
            RSR.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 9) {
                        Circle().fill(RSR.success).frame(width: 9, height: 9)
                        Text(label).font(.rsrLargeTitle).tracking(RSRTracking.largeTitle)
                            .foregroundStyle(RSR.labelPrimary)
                    }
                    Text("24 recordings · 18 min · ready to train")
                        .font(.rsrSubhead).foregroundStyle(RSR.labelSecondary).padding(.top, 8)

                    RSRCard(radius: RSRRadius.card) {
                        VStack(spacing: 0) {
                            ForEach(Array(clips.enumerated()), id: \.element.id) { i, clip in
                                RSRRecordingRow(timestamp: clip.timestamp,
                                                relative: clip.relative, duration: clip.duration)
                                if i < clips.count - 1 {
                                    Divider().overlay(RSR.hairline).padding(.leading, 51)
                                }
                            }
                        }
                    }
                    .padding(.top, 18)

                    Text("+ 19 more recordings")
                        .font(.rsrSubhead).foregroundStyle(RSR.labelTertiary)
                        .frame(maxWidth: .infinity).padding(.top, 14)
                }
                .padding(.horizontal, RSRSpace.screen)
                .padding(.bottom, 120)
            }

            // Primary CTA into the flow
            Button {} label: {
                VStack(spacing: 3) {
                    Text("Review one by one").font(.rsrHeadline).foregroundStyle(.white)
                    Text("Listen, then keep or discard each")
                        .font(.rsrSubhead).foregroundStyle(.white.opacity(0.82))
                }
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(RSR.accentGradient)
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                .rsrShadow(.accentLift)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, RSRSpace.screen)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Headphones pre-flight

struct HeadphonesIntroView: View {
    var body: some View {
        ZStack {
            RSR.canvas.ignoresSafeArea()
            VStack {
                HStack { Button("Cancel") {}.font(.rsrHeadline).foregroundStyle(RSR.accent).buttonStyle(.plain); Spacer() }
                    .padding(.horizontal, RSRSpace.screen).padding(.top, 4)
                Spacer()
                RSRHeadphonesPrompt(count: 24, totalLength: "~18 min total")
                    .padding(.horizontal, 40)
                Spacer()
                VStack(spacing: 12) {
                    RSRPrimaryButton(title: "Start reviewing")
                    Text("Best with headphones in a quiet space")
                        .font(.rsrCaption).foregroundStyle(RSR.labelTertiary)
                }
                .padding(.horizontal, 28).padding(.bottom, 56)
            }
        }
    }
}

// MARK: - Empty state

struct ReviewEmptyView: View {
    var body: some View {
        ZStack {
            RSR.canvas.ignoresSafeArea()
            VStack {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold))
                    Text("Bearing fault").font(.rsrHeadline)
                }.foregroundStyle(RSR.accent).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, RSRSpace.screen).padding(.top, 4)
                Spacer()
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .frame(width: 120, height: 120)
                        .rsrGlass(.regular, radius: 34, elevation: .card)
                        .overlay(Image(systemName: "minus.circle")
                            .font(.system(size: 50, weight: .regular)).foregroundStyle(RSR.labelTertiary))
                        .padding(.bottom, 28)
                    Text("Nothing to review").font(.rsrTitle).foregroundStyle(RSR.labelPrimary)
                    Text("There are no recordings waiting under Bearing fault right now. Record some audio to start training.")
                        .font(.rsrBody).foregroundStyle(RSR.labelSecondary)
                        .multilineTextAlignment(.center).padding(.top, 10).frame(maxWidth: 272)
                }
                .padding(.horizontal, 44)
                Spacer()
                VStack(spacing: 12) {
                    RSRSecondaryButton(title: "Record audio", showsRecordDot: true)
                    Text("Back to labels").font(.rsrHeadline).foregroundStyle(RSR.accent)
                }
                .padding(.horizontal, 28).padding(.bottom, 56)
            }
        }
    }
}

// MARK: - Previews

#Preview("Playing · Light")  { ReviewLabelView(phase: .playing).preferredColorScheme(.light) }
#Preview("Playing · Dark")   { ReviewLabelView(phase: .playing).preferredColorScheme(.dark) }
#Preview("Loading")          { ReviewLabelView(phase: .loading).preferredColorScheme(.light) }
#Preview("Kept")             { ReviewLabelView(phase: .decided(.kept)).preferredColorScheme(.light) }
#Preview("Removed · Dark")   { ReviewLabelView(phase: .decided(.removed)).preferredColorScheme(.dark) }
#Preview("Queue")            { ReviewQueueView().preferredColorScheme(.light) }
#Preview("Headphones · Dark"){ HeadphonesIntroView().preferredColorScheme(.dark) }
#Preview("Empty")            { ReviewEmptyView().preferredColorScheme(.light) }
