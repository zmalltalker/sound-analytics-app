//
//  RSRTypography.swift
//  Rich Sound Recorder — Design System
//
//  San Francisco (the system font), addressed by ROLE. Hierarchy comes
//  from weight and tracking, not color. Every role is bound to a SwiftUI
//  text style, so it scales with the user's Text Size setting across the
//  standard steps AND the five Accessibility sizes (AX1–AX5). The one
//  custom size — the 70pt timer — scales (capped) via @ScaledMetric; use
//  the `.rsrDisplayFont()` modifier, not the fixed `.rsrDisplay` constant.
//  Numbers that change use monospaced digits.
//
//  Dynamic Type is never disabled. Because text grows, layouts must give
//  it room — see the Design System doc, §03 “Type scales with the reader”:
//    • size controls with a 44pt MIN height, never a fixed height;
//    • let names WRAP (lineLimit ≥ 2) before they truncate;
//    • reflow horizontal rows (name + meter + count) to vertical, and let
//      tab-bar labels fall away, at the Accessibility sizes.
//  Verify every screen at .dynamicTypeSize(.accessibility5) before shipping.
//

import SwiftUI

extension Font {

    /// 34pt Heavy — screen titles ("Detect", "Train"). Scales via .largeTitle.
    static let rsrLargeTitle = Font.system(.largeTitle, design: .default, weight: .heavy)

    /// 22pt Bold — card / section titles ("Ready to train"). Scales via .title2.
    static let rsrTitle = Font.system(.title2, design: .default, weight: .bold)

    /// 17pt Semibold — button labels, prominent headlines. Scales via .headline.
    static let rsrHeadline = Font.system(.headline, design: .default, weight: .semibold)

    /// 15pt Medium — body & primary list text. Scales via .subheadline.
    static let rsrBody = Font.system(.subheadline, design: .default, weight: .medium)

    /// 13pt Medium — supporting / subhead text. Scales via .footnote.
    static let rsrSubhead = Font.system(.footnote, design: .default, weight: .medium)

    /// 12pt Semibold — captions, tab labels (often UPPERCASED + tracked). Scales via .caption.
    static let rsrCaption = Font.system(.caption, design: .default, weight: .semibold)

    /// 12pt Monospaced — technical metadata ("48 kHz · MONO · AAC"). Scales via .caption.
    static let rsrMeta = Font.system(.caption, design: .monospaced, weight: .semibold)

    /// 70pt Ultralight — the listening timer / hero numerals.
    /// ⚠️ FIXED size: this constant does NOT scale with Dynamic Type. Prefer the
    /// `.rsrDisplayFont()` modifier below, which scales (capped) via @ScaledMetric.
    /// Kept only for fixed-frame previews and non-scaling contexts.
    static let rsrDisplay = Font.system(size: 70, weight: .ultraLight, design: .default)
}

// MARK: - Display (timer) — Dynamic-Type-aware via @ScaledMetric

/// Scales the 70pt timer relative to .largeTitle, capped at ~96pt so the
/// numerals stay on one line at the largest Accessibility sizes.
struct RSRDisplayFont: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 70
    func body(content: Content) -> some View {
        content.font(.system(size: min(size, 96), weight: .ultraLight))
    }
}

extension View {
    /// Apply to the listening timer so it tracks Dynamic Type (capped at ~96pt).
    func rsrDisplayFont() -> some View { modifier(RSRDisplayFont()) }
}

// MARK: - Ready-made text styles

extension Text {

    /// Tracked, uppercased caption used for status eyebrows ("LISTENING").
    func rsrEyebrow(_ color: Color = RSR.accent) -> some View {
        self.font(.rsrCaption)
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }

    /// Tabular numerals for any value that animates or right-aligns.
    func rsrTabular() -> Text {
        self.monospacedDigit()
    }
}

// MARK: - Tracking constants
//
// SwiftUI `.tracking` is in points. Negative values tighten display type.

enum RSRTracking {
    static let largeTitle: CGFloat = -1.0   // ≈ -0.03em at 34pt
    static let title: CGFloat      = -0.2
    static let display: CGFloat    = -2.0   // ≈ -0.03em at 70pt
    static let eyebrow: CGFloat    = 0.6
}
