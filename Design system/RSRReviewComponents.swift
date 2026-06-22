//
//  RSRReviewComponents.swift
//  Rich Sound Recorder — Design System
//
//  Widgets for the "Review labeled recordings" flow: listen through a
//  label's recordings one at a time and keep or discard each. Built
//  entirely from the existing RSR tokens, typography, and the Liquid
//  Glass surface modifier — same vocabulary as RSRComponents.swift.
//
//  Decision semantics:
//    Keep    = success. The encouraged action gets the filled green
//              gradient — green signals an accepted state, not decoration.
//    Discard = destructive. A red glyph + label inside a glass button,
//              never a red fill. Always pair with an Undo after the fact.
//

import SwiftUI

// MARK: - Shared

enum RSRReview {
    /// The "Keep" success gradient (#34C759 → #28B14A), mirroring RSR.accentGradient's recipe.
    static let keepGradient = LinearGradient(
        colors: [Color(red: 0.204, green: 0.780, blue: 0.349),
                 Color(red: 0.157, green: 0.694, blue: 0.290)],
        startPoint: .top, endPoint: .bottom)
}

// MARK: - Progress header
//
// A thin meter + tabular "n/total" counter. Sits under the nav bar on
// every step of the flow so the queue position is always visible.

struct RSRReviewProgressHeader: View {
    let index: Int
    let total: Int

    var body: some View {
        HStack(spacing: 12) {
            RSRMeter(fraction: total > 0 ? Double(index) / Double(total) : 0)
                .frame(height: 4)
            Text("\(index)/\(total)")
                .font(.rsrSubhead.weight(.semibold))
                .foregroundStyle(RSR.labelSecondary)
                .monospacedDigit()
        }
    }
}

// MARK: - Replay button

struct RSRReplayButton: View {
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .semibold))
                Text("Replay").font(.rsrBody.weight(.semibold))
            }
            .foregroundStyle(RSR.accent)
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .rsrGlass(.thin, radius: 16, elevation: .resting)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Decision bar
//
// The heart of the flow: two large buttons. Keep leads (filled success
// gradient); Discard is a glass button with a destructive red glyph.

struct RSRDecisionBar: View {
    var onDiscard: () -> Void = {}
    var onKeep: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onDiscard) {
                HStack(spacing: 9) {
                    Image(systemName: "xmark").font(.system(size: 18, weight: .bold))
                    Text("Discard").font(.rsrHeadline)
                }
                .foregroundStyle(RSR.danger)
                .frame(maxWidth: .infinity, minHeight: 64)
                .rsrGlass(.thin, radius: 20, fill: RSR.surfaceGlassStrong, elevation: .card)
            }
            .buttonStyle(.plain)

            Button(action: onKeep) {
                HStack(spacing: 9) {
                    Image(systemName: "checkmark").font(.system(size: 18, weight: .bold))
                    Text("Keep").font(.rsrHeadline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(RSRReview.keepGradient)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                )
                .shadow(color: RSR.success.opacity(0.4), radius: 12, y: 8)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Playback waveform
//
// The design-system waveform, two-toned: bars before the playhead use
// `playedColor`, the rest `restColor`, with a glowing playhead line at
// the current position. `progress` is the 0…1 playback fraction.

struct RSRReviewWaveform: View {
    var count: Int = 54
    var amplitude: CGFloat = 150
    var barWidth: CGFloat = 3
    var gap: CGFloat = 3.1
    var seed: Double = 9
    var progress: Double = 0.62
    var playedColor: Color = RSR.accent
    var restColor: Color = RSR.trackFill

    private func height(_ i: Int) -> CGFloat {
        let t = CGFloat(i) / CGFloat(max(count - 1, 1))
        let env = 0.30 + 0.70 * pow(sin(.pi * t), 0.7)
        let r = fract(sin(Double(i) * 12.9898 + seed * 78.233) * 43758.5453)
        return max(5, (0.16 + 0.84 * CGFloat(r)) * amplitude * env)
    }
    private func fract(_ x: Double) -> Double { x - floor(x) }

    var body: some View {
        let cut = Int(Double(count) * progress)
        HStack(alignment: .center, spacing: gap) {
            ForEach(0..<count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(i < cut ? playedColor : restColor)
                    .frame(width: barWidth, height: height(i))
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .leading) {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 1)
                    .fill(playedColor)
                    .frame(width: 2)
                    .shadow(color: playedColor.opacity(0.6), radius: 4)
                    .padding(.vertical, 14)
                    .offset(x: geo.size.width * progress)
            }
        }
    }
}

// MARK: - Download ring
//
// The loading state: a determinate accent ring around a download glyph.
// The recording plays automatically once `progress` reaches 1.

struct RSRDownloadRing: View {
    var progress: Double = 0.38
    var size: CGFloat = 120

    var body: some View {
        ZStack {
            Circle().stroke(RSR.trackFill, lineWidth: 6)
            Circle().trim(from: 0, to: progress)
                .stroke(RSR.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "arrow.down")
                .font(.system(size: size * 0.25, weight: .semibold))
                .foregroundStyle(RSR.accent)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Outcome badge
//
// Shown for a beat after a decision before the next clip loads.
// Kept = filled success circle + check; Removed = glass circle with a
// danger border + xmark.

enum RSRReviewOutcome {
    case kept, removed
    var title: String { self == .kept ? "Kept" : "Removed" }
    var symbol: String { self == .kept ? "checkmark" : "xmark" }
    var tint: Color { self == .kept ? RSR.success : RSR.danger }
}

struct RSROutcomeBadge: View {
    let outcome: RSRReviewOutcome

    var body: some View {
        ZStack {
            Circle().fill(outcome.tint.opacity(0.12))
            Circle().strokeBorder(outcome.tint.opacity(0.25), lineWidth: 1)
            inner
        }
        .frame(width: 120, height: 120)
        .shadow(color: outcome.tint.opacity(0.18), radius: 18, y: 10)
    }

    @ViewBuilder private var inner: some View {
        switch outcome {
        case .kept:
            Circle().fill(RSRReview.keepGradient)
                .frame(width: 84, height: 84)
                .overlay(Image(systemName: "checkmark")
                    .font(.system(size: 38, weight: .bold)).foregroundStyle(.white))
                .shadow(color: RSR.success.opacity(0.4), radius: 12, y: 8)
        case .removed:
            Circle()
                .frame(width: 84, height: 84)
                .rsrGlass(.thin, radius: 42, elevation: .card)
                .overlay(Circle().strokeBorder(RSR.danger.opacity(0.4), lineWidth: 0.5))
                .overlay(Image(systemName: "xmark")
                    .font(.system(size: 36, weight: .bold)).foregroundStyle(RSR.danger))
        }
    }
}

// MARK: - Headphones pre-flight prompt
//
// The one-time intro before the first recording: gradient headphones
// tile, instruction, and a queue summary. Compose a primary button beneath.

struct RSRHeadphonesPrompt: View {
    var count: Int = 24
    var totalLength: String = "~18 min total"

    var body: some View {
        VStack(spacing: 0) {
            Circle().fill(RSR.accentTileGradient)
                .frame(width: 128, height: 128)
                .overlay(Image(systemName: "headphones")
                    .font(.system(size: 54, weight: .regular)).foregroundStyle(.white))
                .rsrShadow(.accentLift)
                .padding(.bottom, 30)

            Text("Put your headphones on")
                .font(.rsrTitle).foregroundStyle(RSR.labelPrimary)
                .multilineTextAlignment(.center)

            Text("You’ll review \(count) recordings one at a time. Listen closely, then keep or discard each.")
                .font(.rsrBody).foregroundStyle(RSR.labelSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .frame(maxWidth: 282)

            HStack(spacing: 8) {
                Circle().fill(RSR.success).frame(width: 7, height: 7)
                Text("\(count) recordings · \(totalLength)")
                    .font(.rsrSubhead.weight(.semibold)).foregroundStyle(RSR.labelSecondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 9)
            .rsrGlass(.thin, radius: 14, elevation: .resting)
            .padding(.top, 26)
        }
    }
}

// MARK: - Recording row (review queue)
//
// A row in the label-detail list: leading play tile, the recorded
// timestamp + relative age, and a trailing tabular duration.

struct RSRRecordingRow: View {
    let timestamp: String
    let relative: String
    let duration: String

    var body: some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(RSR.accentTint)
                .frame(width: 38, height: 38)
                .overlay(Image(systemName: "play.fill")
                    .font(.system(size: 13)).foregroundStyle(RSR.accent))
            VStack(alignment: .leading, spacing: 3) {
                Text(timestamp).font(.rsrBody.weight(.semibold)).foregroundStyle(RSR.labelPrimary)
                Text(relative).font(.system(size: 12, weight: .medium)).foregroundStyle(RSR.labelSecondary)
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
