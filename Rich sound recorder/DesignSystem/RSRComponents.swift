//
//  RSRComponents.swift
//  Rich Sound Recorder — Design System
//
//  Custom widgets built entirely from the tokens, typography, and the
//  Liquid Glass surface modifier. Each maps 1:1 to a component documented
//  on the Design System page.
//

import SwiftUI

// MARK: - Buttons
//
// Primary   — accent gradient, one per screen, the main forward action.
// Secondary — glass fill with accent label, parallel actions.
// Tonal     — accent text on 10% tint, inline utilities (Switch, Manage).
// Destructive intent is shown by a red dot/square inside an otherwise
// standard button — not a fully red fill (except a final Stop).

struct RSRPrimaryButton: View {
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.rsrHeadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(RSR.accentGradient)
                .clipShape(RoundedRectangle(cornerRadius: RSRRadius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: RSRRadius.control, style: .continuous)
                        .strokeBorder(.white.opacity(0.4), lineWidth: 0.5)
                )
                .rsrShadow(.accentLift)
        }
        .buttonStyle(.plain)
    }
}

struct RSRSecondaryButton: View {
    let title: String
    var showsRecordDot: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if showsRecordDot {
                    Circle().fill(RSR.danger).frame(width: 11, height: 11)
                }
                Text(title)
                    .font(.rsrHeadline)
                    .foregroundStyle(RSR.accent)
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .rsrGlass(.thin, radius: RSRRadius.control,
                      fill: RSR.surfaceGlassStrong, elevation: .resting)
        }
        .buttonStyle(.plain)
    }
}

struct RSRTonalButton: View {
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.rsrBody.weight(.semibold))
                .foregroundStyle(RSR.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RSR.accentTint)
                .clipShape(RoundedRectangle(cornerRadius: RSRRadius.chip, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass card

struct RSRCard<Content: View>: View {
    var radius: CGFloat = RSRRadius.sheet
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(RSRSpace.card)
            .frame(maxWidth: .infinity, alignment: .leading)
            .rsrGlass(.regular, radius: radius)
    }
}

// MARK: - Waveform
//
// One procedural generator drives every waveform: bars under a sine
// envelope (loudest in the middle). Screens vary count, amplitude, bar
// width, and color. Color encodes state — accent when live/selected,
// muted blue-gray when passive. A waveform always implies real audio.

struct RSRWaveform: View {
    var count: Int = 48
    var amplitude: CGFloat = 132
    var barWidth: CGFloat = 3
    var gap: CGFloat = 3.4
    var seed: Double = 11
    var color: Color = RSR.accent

    private func height(_ i: Int) -> CGFloat {
        let t = CGFloat(i) / CGFloat(max(count - 1, 1))
        let env = 0.30 + 0.70 * pow(sin(.pi * t), 0.7)
        let r = fract(sin(Double(i) * 12.9898 + seed * 78.233) * 43758.5453)
        return max(5, (0.16 + 0.84 * CGFloat(r)) * amplitude * env)
    }
    private func fract(_ x: Double) -> Double { x - floor(x) }

    var body: some View {
        HStack(alignment: .center, spacing: gap) {
            ForEach(0..<count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color)
                    .frame(width: barWidth, height: height(i))
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Live hero waveform (accent, adapts to appearance).
    static var hero: RSRWaveform { .init(amplitude: 132, color: RSR.accent) }
    /// Passive / muted state.
    static var muted: RSRWaveform { .init(amplitude: 60, seed: 7, color: RSR.trackFill) }
}

// MARK: - Project selector
//
// The active project is always visible and one tap from switching.
// `full` is the home/Train card; `compact` is the app-bar chip. Both open
// the same switcher sheet.

struct RSRProjectSelector: View {
    let name: String
    var role: String = "Active project"
    var action: () -> Void = {}

    var body: some View {
        HStack(spacing: 11) {
            RSRGlyphTile()
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.rsrBody.weight(.semibold)).foregroundStyle(RSR.labelPrimary)
                Text(role).font(.rsrSubhead).foregroundStyle(RSR.labelSecondary)
            }
            Spacer()
            RSRTonalButton(title: "Switch", action: action)
        }
        .padding(.vertical, 10)
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .rsrGlass(.regular, radius: RSRRadius.control, elevation: .card)
    }
}

struct RSRProjectChip: View {
    let name: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(name).font(.rsrBody.weight(.semibold)).foregroundStyle(RSR.labelPrimary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(RSR.labelTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .rsrGlass(.thin, radius: 15, elevation: .resting)
        }
        .buttonStyle(.plain)
    }
}

/// The accent glyph tile with a 3-bar mini waveform, used to mark projects.
struct RSRGlyphTile: View {
    var size: CGFloat = 34
    var body: some View {
        RoundedRectangle(cornerRadius: RSRRadius.tile, style: .continuous)
            .fill(RSR.accentTileGradient)
            .frame(width: size, height: size)
            .overlay {
                HStack(spacing: 2) {
                    bar(7); bar(15); bar(9)
                }
            }
    }
    private func bar(_ h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2).fill(.white).frame(width: 2.4, height: h)
    }
}

// MARK: - Label row
//
// status dot + name + readiness signal (clip-count meter OR a state tag).
// Dot color encodes readiness: green ready, amber needs audio, red error.

enum RSRReadiness {
    case ready(clips: Int, fraction: Double)
    case needsAudio
    case error(String)

    var dotColor: Color {
        switch self {
        case .ready:      return RSR.success
        case .needsAudio: return RSR.warning
        case .error:      return RSR.danger
        }
    }
}

struct RSRLabelRow: View {
    let name: String
    let state: RSRReadiness

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(state.dotColor).frame(width: 8, height: 8)
            Text(name).font(.rsrBody.weight(.semibold)).foregroundStyle(RSR.labelPrimary)
            Spacer()
            switch state {
            case let .ready(clips, fraction):
                RSRMeter(fraction: fraction).frame(width: 64)
                Text("\(clips)")
                    .font(.rsrSubhead.weight(.semibold))
                    .foregroundStyle(RSR.labelSecondary)
                    .monospacedDigit()
                    .frame(width: 30, alignment: .trailing)
            case .needsAudio:
                Text("Needs audio").font(.rsrSubhead.weight(.semibold)).foregroundStyle(RSR.warning)
            case let .error(msg):
                Text(msg).font(.rsrSubhead.weight(.semibold)).foregroundStyle(RSR.danger)
            }
        }
        .frame(minHeight: 44)
    }
}

// MARK: - Confidence / progress meter

struct RSRMeter: View {
    /// 0...1
    let fraction: Double
    var tint: Color = RSR.accent
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(RSR.trackFill)
                Capsule().fill(tint).frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Event (detection result) card

struct RSREventCard: View {
    let name: String
    let timeRange: String
    /// 0...1
    let confidence: Double
    /// High-confidence events lead in accent; low-confidence in secondary.
    var isPrimary: Bool = true

    var body: some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isPrimary ? RSR.accent : RSR.labelSecondary)
                .frame(width: 4, height: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.system(size: 16, weight: .semibold)).foregroundStyle(RSR.labelPrimary)
                Text(timeRange).font(.rsrSubhead).foregroundStyle(RSR.labelSecondary).monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text("\(Int(confidence * 100))%")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isPrimary ? RSR.accent : RSR.labelSecondary)
                RSRMeter(fraction: confidence,
                         tint: isPrimary ? RSR.accent : RSR.labelSecondary,
                         height: 5)
                    .frame(width: 54)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .rsrGlass(.thin, radius: RSRRadius.control, elevation: .resting)
    }
}

// MARK: - List row (settings / models)

struct RSRListRow: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String = "rectangle.stack"
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(RSR.accent)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.rsrBody.weight(.semibold)).foregroundStyle(RSR.labelPrimary)
                if let subtitle {
                    Text(subtitle).font(.system(size: 12, weight: .medium)).foregroundStyle(RSR.labelSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RSR.labelTertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .rsrGlass(.regular, radius: RSRRadius.control)
    }
}

// MARK: - Tab bar
//
// A floating glass island, inset from the edges — the only thick-blur
// surface. Active = filled accent icon + accent caption; inactive =
// outline icon + label at 50% hue. Hidden during sign-in.

struct RSRTab: Identifiable {
    let id = UUID()
    let title: String
    let icon: String        // SF Symbol (outline)
    let iconActive: String  // SF Symbol (filled)
}

struct RSRTabBar: View {
    let tabs: [RSRTab]
    @Binding var selection: Int
    var badges: [RSRBadgeKind] = []

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                let active = index == selection
                let badge = badges.indices.contains(index) ? badges[index] : .none
                Button {
                    selection = index
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: active ? tab.iconActive : tab.icon)
                            .font(.system(size: 21, weight: .regular))
                            .frame(width: 28, height: 24)
                            .rsrTabBadge(badge, ringColor: RSR.surfaceTabBar)
                        Text(tab.title).font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(active ? RSR.accent : RSR.labelSecondary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 66)
        .padding(.horizontal, 8)
        .rsrGlass(.thick, radius: RSRRadius.tabBar, fill: RSR.surfaceTabBar, elevation: .floating)
        .padding(.horizontal, 14)
    }
}

// Default RSR destinations.
extension RSRTabBar {
    static let standardTabs = [
        RSRTab(title: "Train",    icon: "waveform",        iconActive: "waveform"),
        RSRTab(title: "Detect",   icon: "dot.scope",       iconActive: "dot.scope"),
        RSRTab(title: "Models",   icon: "square.stack.3d.up", iconActive: "square.stack.3d.up.fill"),
        RSRTab(title: "Settings", icon: "slider.horizontal.3", iconActive: "slider.horizontal.3")
    ]
}
