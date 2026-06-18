//
//  RSRColor+Assets.swift
//  Rich Sound Recorder — Design System
//
//  OPTIONAL — asset-catalog-backed tokens.
//
//  `RSRColor.swift` defines every token in code via Color(light:dark:).
//  That is the source of truth and needs no resources. If your team would
//  rather manage colors in Xcode's asset catalog, add `Colors.xcassets`
//  to the target and use this file INSTEAD of the token block in
//  RSRColor.swift (delete or comment one of the two — they define the
//  same `RSR.*` names).
//
//  Every Color Set in Colors.xcassets carries an "Any" (light) and a
//  "Dark" appearance, so these resolve automatically just like the code
//  tokens. Names map 1:1:  RSR.accent → "RSRAccent", etc.
//

import SwiftUI

/*  Uncomment to switch the system onto the asset catalog.

enum RSR {
    // Brand & accent
    static let accent       = Color("RSRAccent")
    static let accentOnDark = Color("RSRAccentOnDark")
    static let accentTint   = Color("RSRAccentTint")
    static let accentGradient = LinearGradient(
        colors: [Color("RSRAccentGradientTop"), Color("RSRAccentGradientBottom")],
        startPoint: .top, endPoint: .bottom)
    static let accentTileGradient = LinearGradient(
        stops: [.init(color: Color("RSRAccentGradientTop"), location: 0),
                .init(color: Color(hex: 0x0A6FFF), location: 0.68),
                .init(color: Color(hex: 0x0A5BDD), location: 1)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    // Status
    static let success = Color("RSRSuccess")
    static let warning = Color("RSRWarning")
    static let danger  = Color("RSRDanger")
    static let utilityPurple = Color("RSRUtilityPurple")
    static let utilityTeal   = Color("RSRUtilityTeal")

    // Labels
    static let labelPrimary   = Color("RSRLabelPrimary")
    static let labelSecondary = Color("RSRLabelSecondary")
    static let labelTertiary  = Color("RSRLabelTertiary")

    // Surfaces / materials
    static let surfaceGlass       = Color("RSRSurfaceGlass")
    static let surfaceGlassStrong = Color("RSRSurfaceGlassStrong")
    static let surfaceTabBar      = Color("RSRSurfaceTabBar")
    static let glassBorder        = Color("RSRGlassBorder")
    static let glassHighlight     = Color("RSRGlassHighlight")

    // Lines & tracks
    static let hairline  = Color("RSRHairline")
    static let trackFill = Color("RSRTrackFill")

    // Canvas
    static let canvas = LinearGradient(
        colors: [Color("RSRCanvasTop"), Color("RSRCanvasBottom")],
        startPoint: .top, endPoint: .bottom)
}

*/
