import SwiftUI

enum RSRReview {
    static let keepGradient = LinearGradient(
        colors: [
            Color(red: 0.204, green: 0.780, blue: 0.349),
            Color(red: 0.157, green: 0.694, blue: 0.290)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

struct RSRReviewProgressHeader: View {
    let index: Int
    let total: Int

    var body: some View {
        HStack(spacing: 12) {
            RSRMeter(fraction: total > 0 ? Double(index) / Double(total) : 0)
                .frame(maxWidth: .infinity)
                .frame(height: 4)

            Text("\(index)/\(total)")
                .font(.rsrSubhead.weight(.semibold))
                .foregroundStyle(RSR.labelSecondary)
                .monospacedDigit()
        }
    }
}

struct RSRReplayButton: View {
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .semibold))
                Text("Replay")
                    .font(.rsrBody.weight(.semibold))
            }
            .foregroundStyle(RSR.accent)
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .rsrGlass(.thin, radius: 16, elevation: .resting)
        }
        .buttonStyle(.plain)
    }
}

struct RSRDecisionBar: View {
    var isEnabled: Bool = true
    var onDiscard: () -> Void = {}
    var onKeep: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onDiscard) {
                HStack(spacing: 9) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                    Text("Discard")
                        .font(.rsrHeadline)
                }
                .foregroundStyle(RSR.danger)
                .frame(maxWidth: .infinity, minHeight: 64)
                .rsrGlass(.thin, radius: 20, fill: RSR.surfaceGlassStrong, elevation: .card)
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)

            Button(action: onKeep) {
                HStack(spacing: 9) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                    Text("Keep")
                        .font(.rsrHeadline)
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
            .disabled(!isEnabled)
        }
        .opacity(isEnabled ? 1 : 0.4)
    }
}

struct RSRReviewWaveform: View {
    var count: Int = 54
    var amplitude: CGFloat = 150
    var barWidth: CGFloat = 3
    var gap: CGFloat = 3.1
    var seed: Double = 9
    var progress: Double = 0.62
    var playedColor: Color = RSR.accent
    var restColor: Color = RSR.trackFill

    private func height(_ index: Int) -> CGFloat {
        let t = CGFloat(index) / CGFloat(max(count - 1, 1))
        let envelope = 0.30 + 0.70 * pow(sin(.pi * t), 0.7)
        let random = fract(sin(Double(index) * 12.9898 + seed * 78.233) * 43758.5453)
        return max(5, (0.16 + 0.84 * CGFloat(random)) * amplitude * envelope)
    }

    private func fract(_ value: Double) -> Double {
        value - floor(value)
    }

    var body: some View {
        let clampedProgress = min(max(progress, 0), 1)
        let cut = Int(Double(count) * clampedProgress)

        HStack(alignment: .center, spacing: gap) {
            ForEach(0..<count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(index < cut ? playedColor : restColor)
                    .frame(width: barWidth, height: height(index))
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .leading) {
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 1)
                    .fill(playedColor)
                    .frame(width: 2)
                    .shadow(color: playedColor.opacity(0.6), radius: 4)
                    .padding(.vertical, 14)
                    .offset(x: geometry.size.width * clampedProgress)
            }
        }
    }
}

struct RSRDownloadRing: View {
    var progress: Double = 0.38
    var size: CGFloat = 120

    var body: some View {
        ZStack {
            Circle()
                .stroke(RSR.trackFill, lineWidth: 6)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(RSR.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Image(systemName: "arrow.down")
                .font(.system(size: size * 0.25, weight: .semibold))
                .foregroundStyle(RSR.accent)
        }
        .frame(width: size, height: size)
    }
}

enum RSRReviewOutcome {
    case kept
    case removed

    var title: String {
        switch self {
        case .kept:
            return "Kept"
        case .removed:
            return "Removed"
        }
    }

    var symbol: String {
        switch self {
        case .kept:
            return "checkmark"
        case .removed:
            return "xmark"
        }
    }

    var tint: Color {
        switch self {
        case .kept:
            return RSR.success
        case .removed:
            return RSR.danger
        }
    }
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

    @ViewBuilder
    private var inner: some View {
        switch outcome {
        case .kept:
            Circle()
                .fill(RSRReview.keepGradient)
                .frame(width: 84, height: 84)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                }
                .shadow(color: RSR.success.opacity(0.4), radius: 12, y: 8)

        case .removed:
            Circle()
                .frame(width: 84, height: 84)
                .rsrGlass(.thin, radius: 42, elevation: .card)
                .overlay(Circle().strokeBorder(RSR.danger.opacity(0.4), lineWidth: 0.5))
                .overlay {
                    Image(systemName: "xmark")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(RSR.danger)
                }
        }
    }
}

struct RSRHeadphonesPrompt: View {
    var count: Int = 24
    var totalLength: String = "~18 min total"

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(RSR.accentTileGradient)
                .frame(width: 128, height: 128)
                .overlay {
                    Image(systemName: "headphones")
                        .font(.system(size: 54, weight: .regular))
                        .foregroundStyle(.white)
                }
                .rsrShadow(.accentLift)
                .padding(.bottom, 30)

            Text("Put your headphones on")
                .font(.rsrTitle)
                .foregroundStyle(RSR.labelPrimary)
                .multilineTextAlignment(.center)

            Text("You’ll review \(count) recordings one at a time. Listen closely, then keep or discard each.")
                .font(.rsrBody)
                .foregroundStyle(RSR.labelSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .frame(maxWidth: 282)

            HStack(spacing: 8) {
                Circle()
                    .fill(RSR.success)
                    .frame(width: 7, height: 7)

                Text("\(count) recordings · \(totalLength)")
                    .font(.rsrSubhead.weight(.semibold))
                    .foregroundStyle(RSR.labelSecondary)
            }
            .padding(.top, 18)
        }
    }
}
