//
//  RSRTheme.swift
//  Rich Sound Recorder — Design System
//
//  Non-color tokens: spacing, corner radius, and elevation (shadows).
//  Spacing steps in multiples of four. Elevation is expressed as a soft
//  ambient shadow — the inner top highlight that completes each level
//  lives in RSRSurface (it needs an overlay, not just a shadow).
//

import SwiftUI

// MARK: - Spacing (4-pt grid)

enum RSRSpace {
    static let xs: CGFloat  = 4
    static let sm: CGFloat  = 8
    static let tight: CGFloat = 11   // dense button stacks
    static let md: CGFloat  = 14     // default stack gap
    static let card: CGFloat = 18    // card inner padding
    static let screen: CGFloat = 22  // screen horizontal margin
    static let lg: CGFloat  = 28

    /// Minimum interactive target. Never go below this.
    static let minHitTarget: CGFloat = 44
}

// MARK: - Corner radius

enum RSRRadius {
    static let tile: CGFloat    = 10   // glyph tiles
    static let chip: CGFloat    = 13   // tonal pills
    static let control: CGFloat = 18   // buttons, rows
    static let card: CGFloat    = 22
    static let sheet: CGFloat   = 26
    static let tabBar: CGFloat  = 33   // capsule island
    static let screen: CGFloat  = 50   // device screen mask
}

// MARK: - Elevation

struct RSRElevation {
    let color: Color
    let radius: CGFloat
    let y: CGFloat

    /// e1 · resting — secondary buttons, subtle lift.
    static let resting = RSRElevation(color: .black.opacity(0.06), radius: 14, y: 4)
    /// e2 · card — the standard glass card.
    static let card = RSRElevation(color: .black.opacity(0.08), radius: 30, y: 10)
    /// e2 · card on dark — darker, deeper.
    static let cardDark = RSRElevation(color: .black.opacity(0.50), radius: 36, y: 14)
    /// e3 · accent lift — colored glow under filled buttons.
    static let accentLift = RSRElevation(color: Color(hex: 0x0A84FF).opacity(0.40), radius: 22, y: 8)
    /// e4 · floating — tab bar & device.
    static let floating = RSRElevation(color: .black.opacity(0.28), radius: 60, y: 30)
}

extension View {
    /// Applies an RSR elevation shadow.
    func rsrShadow(_ e: RSRElevation) -> some View {
        self.shadow(color: e.color, radius: e.radius, x: 0, y: e.y)
    }
}
