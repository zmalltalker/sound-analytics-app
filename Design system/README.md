# Rich Sound Recorder — SwiftUI Specification

The native counterpart to the iOS Design System page. A small, dependency-free
set of Swift files that encode the **Liquid Glass** system: semantic tokens,
the San Francisco type ramp, the glass material recipe, and every custom widget.

Drop these into an iOS 17+ SwiftUI target. No packages, no assets required
(SF Symbols only).

## Files

| File | Contents |
|------|----------|
| `RSRColor.swift` | Semantic color tokens. A dynamic `Color(light:dark:)` initializer resolves each token per appearance. **Source of truth** — mirror as a `.xcassets` Color Set if you prefer the asset catalog. |
| `RSRTypography.swift` | `Font` roles (`.rsrLargeTitle`, `.rsrBody`, …), tracking constants, and `Text` helpers (`.rsrEyebrow`, `.rsrTabular`). |
| `RSRTheme.swift` | Non-color tokens: `RSRSpace`, `RSRRadius`, `RSRElevation` + the `.rsrShadow()` modifier. |
| `RSRSurface.swift` | The glass recipe as `.rsrGlass(_:radius:)` — blur + tint + hairline border + inner top highlight, in three weights. |
| `RSRComponents.swift` | Custom widgets (buttons, waveform, project selector, label row, meter, event card, list row, tab bar). |
| `DetectView.swift` | Reference assembly of the Detect results screen, with light + dark previews. |
| `Colors.xcassets/` | Xcode asset catalog — every token as a Color Set with Any/Dark appearances. |
| `RSRColor+Assets.swift` | Optional catalog-backed token block — use instead of the code tokens in `RSRColor.swift` (same `RSR.*` names). |

## Principles

1. **Glass, not chrome.** Surfaces are translucent and defer to content. Use `.rsrGlass()`; never an opaque gray panel.
2. **One accent, earned.** `RSR.accent` carries all primary action and selection. `RSR.success / warning / danger` signal state only.
3. **Light & dark are equal.** Every token is dynamic. Build from tokens and appearance inverts for free.
4. **Calm hierarchy.** Weight and size, not color. Secondary text = same hue, lower opacity (`RSR.labelSecondary`).
5. **Depth through light.** Elevation = soft ambient shadow + 1px inner top highlight (both baked into `.rsrGlass()`).

## Tokens at a glance

**Color (semantic)** — `accent`, `accentOnDark`, `accentTint`, `accentGradient`; `success`, `warning`, `danger`, `utilityPurple/Teal`; `labelPrimary/Secondary/Tertiary`; `surfaceGlass/Strong`, `surfaceTabBar`, `glassBorder`, `glassHighlight`; `hairline`, `trackFill`; `canvas`.

**Type** — `display 70/UltraLight` · `largeTitle 34/Heavy` · `title 22/Bold` · `headline 17/Semibold` · `body 15/Medium` · `subhead 13/Medium` · `caption 12/Semibold` · `meta 12/Mono`.

**Shape** — radius `tile 10 · chip 13 · control 18 · card 22 · sheet 26 · tabBar 33 · screen 50`. Spacing on a 4-pt grid: screen margin 22, card padding 18, stack gap 14, tight 11. Hit target ≥ 44.

**Elevation** — `resting · card · accentLift · floating`.

**Materials** — `thin` (blur ~20: buttons, chips, rows) · `regular` (blur ~28: cards, sheets) · `thick` (blur ~34: tab bar only).

## Usage

```swift
// A glass card with a primary action
RSRCard {
    Text("Ready to train").font(.rsrTitle).foregroundStyle(RSR.labelPrimary)
    RSRLabelRow(name: "Bearing fault", state: .ready(clips: 24, fraction: 1.0))
    RSRLabelRow(name: "Impeller wear", state: .needsAudio)
}
RSRPrimaryButton(title: "Start training") { startTraining() }

// Any surface
someView.rsrGlass(.regular, radius: RSRRadius.card)
```

## Notes for handoff

- The `Color(light:dark:)` helper is the explicit, code-visible mapping. If your
  team prefers the asset catalog, create matching Color Sets — the hex values
  in `RSRColor.swift` are authoritative either way.
- `RSRWaveform` reproduces the design-system generator exactly (sine envelope +
  hashed amplitude). Pass a fixed `seed` for a stable shape, or animate
  `amplitude` from a live level meter.
- Tab bar SF Symbols are starting points (`waveform`, `dot.scope`,
  `square.stack.3d.up`, `slider.horizontal.3`); swap for custom symbols to
  match the artboards pixel-for-pixel.
- Targets iOS 17+ for `RoundedRectangle(style: .continuous)` + `Material`.
  Backwards to iOS 15 works with minor tweaks.

_v1.0 — pairs with “Rich Sound Recorder — Design System.dc.html”._
