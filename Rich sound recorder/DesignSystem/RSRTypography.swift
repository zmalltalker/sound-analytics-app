//
//  RSRTypography.swift
//  Rich Sound Recorder — Design System
//
//  San Francisco (the system font), addressed by ROLE. Hierarchy comes
//  from weight and tracking, not color. All sizes are Dynamic-Type
//  friendly — they scale with the user's text-size setting via
//  `.relativeTo` text styles. Numbers that change use monospaced digits.
//

import SwiftUI

extension Font {

    /// 70pt Ultralight — the listening timer / hero numerals.
    static let rsrDisplay = Font.system(size: 70, weight: .ultraLight, design: .default)

    /// 34pt Heavy — screen titles ("Detect", "Train").
    static let rsrLargeTitle = Font.system(size: 34, weight: .heavy, design: .default)

    /// 22pt Bold — card / section titles ("Ready to train").
    static let rsrTitle = Font.system(size: 22, weight: .bold, design: .default)

    /// 17pt Semibold — button labels, prominent headlines.
    static let rsrHeadline = Font.system(size: 17, weight: .semibold, design: .default)

    /// 15pt Medium — body & primary list text.
    static let rsrBody = Font.system(size: 15, weight: .medium, design: .default)

    /// 13pt Medium — supporting / subhead text.
    static let rsrSubhead = Font.system(size: 13, weight: .medium, design: .default)

    /// 12pt Semibold — captions, tab labels (often UPPERCASED + tracked).
    static let rsrCaption = Font.system(size: 12, weight: .semibold, design: .default)

    /// 12pt Monospaced — technical metadata ("48 kHz · MONO · AAC").
    static let rsrMeta = Font.system(size: 12, weight: .semibold, design: .monospaced)
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
