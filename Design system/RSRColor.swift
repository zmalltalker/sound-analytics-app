//
//  RSRColor.swift
//  Rich Sound Recorder — Design System
//
//  Semantic color tokens. Screens reference colors by ROLE (RSR.accent,
//  RSR.labelSecondary, RSR.surfaceGlass) — never raw hex. Every token
//  resolves to a light and a dark value automatically via the trait
//  environment, so components invert with the system appearance.
//
//  Recommended: also mirror these as a Color Set in an .xcassets catalog
//  (Any / Dark appearances). The dynamic UIColor initializer below is the
//  code-only equivalent and is the source of truth for this spec.
//

import SwiftUI

// MARK: - Dynamic color helper

extension Color {
    /// Builds a Color that resolves differently in light vs. dark appearance.
    init(light: UInt32, dark: UInt32, lightAlpha: Double = 1, darkAlpha: Double = 1) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }

    /// Single-value token (same in both appearances).
    init(hex: UInt32, alpha: Double = 1) {
        self.init(uiColor: UIColor(hex: hex, alpha: alpha))
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue:  Double(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}

// MARK: - Semantic tokens

enum RSR {

    // ── Brand & accent ──────────────────────────────────────────────
    /// Primary action & selection. The system's only brand hue.
    static let accent       = Color(hex: 0x0A84FF)
    /// Accent text on dark surfaces (slightly lighter for contrast).
    static let accentOnDark  = Color(hex: 0x409CFF)
    /// 10% accent wash — tonal pills, selected fills. Dark uses 18%.
    static let accentTint    = Color(light: 0x0A84FF, dark: 0x0A84FF,
                                     lightAlpha: 0.10, darkAlpha: 0.18)
    /// Filled-button gradient (top → bottom).
    static let accentGradient = LinearGradient(
        colors: [Color(hex: 0x3A9BFF), Color(hex: 0x0A84FF)],
        startPoint: .top, endPoint: .bottom
    )
    /// Glyph-tile gradient (top-leading → bottom-trailing).
    static let accentTileGradient = LinearGradient(
        stops: [.init(color: Color(hex: 0x3A9BFF), location: 0),
                .init(color: Color(hex: 0x0A6FFF), location: 0.68),
                .init(color: Color(hex: 0x0A5BDD), location: 1)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // ── Status ──────────────────────────────────────────────────────
    static let success = Color(light: 0x34C759, dark: 0x30D158)   // ready / has audio
    static let warning = Color(hex: 0xFF9F0A)                      // needs audio / attention
    static let danger  = Color(light: 0xFF3B30, dark: 0xFF453A)   // record, stop, destructive
    static let utilityPurple = Color(hex: 0x5E5CE6)
    static let utilityTeal   = Color(hex: 0x30B0A6)

    // ── Text / labels (opacity steps of one hue) ────────────────────
    static let labelPrimary   = Color(light: 0x0B0B0F, dark: 0xFFFFFF)
    static let labelSecondary = Color(light: 0x3C3C43, dark: 0xEBEBF5,
                                      lightAlpha: 0.60, darkAlpha: 0.60)
    static let labelTertiary  = Color(light: 0x3C3C43, dark: 0xEBEBF5,
                                      lightAlpha: 0.40, darkAlpha: 0.40)

    // ── Surfaces / materials (see RSRSurface for the full recipe) ────
    /// Translucent glass fill used under .ultraThinMaterial-style blur.
    static let surfaceGlass = Color(light: 0xFFFFFF, dark: 0x1E1F24,
                                    lightAlpha: 0.66, darkAlpha: 0.60)
    /// Stronger glass for prominent buttons / sheets.
    static let surfaceGlassStrong = Color(light: 0xFFFFFF, dark: 0x28292E,
                                          lightAlpha: 0.70, darkAlpha: 0.70)
    /// The floating tab bar fill.
    static let surfaceTabBar = Color(light: 0xFFFFFF, dark: 0x1A1B1F,
                                     lightAlpha: 0.62, darkAlpha: 0.62)
    /// Hairline border on glass.
    static let glassBorder = Color(light: 0xFFFFFF, dark: 0xFFFFFF,
                                   lightAlpha: 0.85, darkAlpha: 0.10)
    /// Inner top highlight (the "light source" line).
    static let glassHighlight = Color(light: 0xFFFFFF, dark: 0xFFFFFF,
                                      lightAlpha: 0.70, darkAlpha: 0.06)

    // ── Lines & tracks ──────────────────────────────────────────────
    static let hairline = Color(light: 0x3C3C43, dark: 0xFFFFFF,
                                lightAlpha: 0.12, darkAlpha: 0.10)
    static let trackFill = Color(light: 0x7890B4, dark: 0xFFFFFF,
                                 lightAlpha: 0.20, darkAlpha: 0.14)

    // ── App canvas background ───────────────────────────────────────
    static let canvas = LinearGradient(
        colors: [Color(light: 0xF6F8FB, dark: 0x0A0B0D),
                 Color(light: 0xECEFF4, dark: 0x000000)],
        startPoint: .top, endPoint: .bottom
    )
}
