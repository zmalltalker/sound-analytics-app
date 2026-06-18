//
//  RSRSurface.swift
//  Rich Sound Recorder — Design System
//
//  The Liquid Glass recipe, as a reusable modifier. Every surface is the
//  same construction: a translucent fill over a heavy backdrop blur with
//  boosted saturation, a hairline border, and a one-pixel inner top
//  highlight (the suggested light source). Three blur weights cover the
//  system.
//
//  SwiftUI exposes blur via `Material`. Use the modifier's `.material`
//  parameter to pick the weight; the fill tint + border + highlight are
//  layered on top to match the tokens exactly.
//

import SwiftUI

enum RSRMaterialWeight {
    case thin      // blur ~20 — buttons, chips, list rows
    case regular   // blur ~28 — cards, model rows, sheets
    case thick     // blur ~34 — the floating tab bar ONLY

    var material: Material {
        switch self {
        case .thin:    return .ultraThinMaterial
        case .regular: return .thinMaterial
        case .thick:   return .regularMaterial
        }
    }
}

struct RSRGlass: ViewModifier {
    var weight: RSRMaterialWeight = .regular
    var radius: CGFloat = RSRRadius.card
    var fill: Color = RSR.surfaceGlass
    var elevation: RSRElevation = .card

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // 1 — system blur (saturation boost is built into Material)
                    Rectangle()
                        .fill(weight.material)
                    // 2 — token tint over the blur
                    fill
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                // 3 — hairline border
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(RSR.glassBorder, lineWidth: 0.5)
            )
            .overlay(alignment: .top) {
                // 4 — inner top highlight: a 1px line just inside the top edge
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .inset(by: 0.5)
                    .stroke(RSR.glassHighlight, lineWidth: 1)
                    .mask(
                        LinearGradient(colors: [.white, .clear],
                                       startPoint: .top, endPoint: .center)
                    )
            }
            .rsrShadow(elevation)
    }
}

extension View {
    /// Wraps the view in a Liquid Glass surface.
    /// - Parameters:
    ///   - weight: blur weight (thin / regular / thick).
    ///   - radius: corner radius token.
    func rsrGlass(_ weight: RSRMaterialWeight = .regular,
                  radius: CGFloat = RSRRadius.card,
                  fill: Color = RSR.surfaceGlass,
                  elevation: RSRElevation = .card) -> some View {
        modifier(RSRGlass(weight: weight, radius: radius, fill: fill, elevation: elevation))
    }
}
