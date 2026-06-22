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
| `RSRReviewComponents.swift` | Review-flow widgets: progress header, replay button, **decision bar (Keep / Discard)**, split playback waveform with playhead, download ring, outcome badge, headphones prompt, recording row. |
| `RSRTrainingComponents.swift` | Training-flow widgets: live pulsing dot, single gradient **progress bar** (with shimmer), connected **phase stepper** (done / current / queued / complete), the **training sheet** (in-progress ↔ complete), the collapsed **training bar**, and the `.rsrTabBadge()` running/ready tab indicator. |
| `DetectView.swift` | Reference assembly of the Detect results screen, with light + dark previews. |
| `ReviewLabelView.swift` | Reference assembly of the **Review labeled recordings** flow — queue entry, headphones pre-flight, loading, playing, just-decided, and empty — with light + dark previews. |
| `TrainingFlowView.swift` | Reference assembly of the **Training in progress** flow — sheet (in-progress + complete) over the Train screen, and the Train screen with the collapsed bar pinned — with light + dark previews. |
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

**Type** — `display 70/UltraLight` · `largeTitle 34/Heavy` · `title 22/Bold` · `headline 17/Semibold` · `body 15/Medium` · `subhead 13/Medium` · `caption 12/Semibold` · `meta 12/Mono`. Every role is bound to a SwiftUI text style and **scales with Dynamic Type**; sizes shown are the Large default. The 70pt timer scales (capped) via `.rsrDisplayFont()`.

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

- **Dynamic Type is supported, not optional.** Every `Font` role binds to a
  text style, so text scales with the reader's Text Size setting (standard +
  AX1–AX5); the 70pt timer uses `.rsrDisplayFont()` (@ScaledMetric, capped).
  Because text grows, components must give it room — **44pt min-height, never a
  fixed height; names wrap before they truncate; horizontal rows reflow to
  vertical at AX sizes.** Verify screens at `.dynamicTypeSize(.accessibility5)`.
  See §03 “Type scales with the reader” in the Design System doc.
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

### Review flow (`RSRReviewComponents` / `ReviewLabelView`)

- The flow triages a selected label's recordings one at a time: **download →
  auto-play → replay / keep / discard → brief confirmation → next.** A one-time
  headphones prompt precedes the first clip.
- **Keep = success, Discard = destructive.** `RSRDecisionBar` gives Keep the
  filled `RSRReview.keepGradient` (green signals an accepted state) and renders
  Discard as a glass button with a `RSR.danger` glyph — never a red fill. Pair
  every decision with the `Undo` affordance shown in `ReviewLabelView`.
- `RSRReviewWaveform` is the standard generator, two-toned at `progress` with a
  glowing playhead. Drive `progress` from the player's `currentTime / duration`.
- `RSRDownloadRing(progress:)` is determinate; flip to `.playing` when it hits 1
  so playback starts automatically. Swap in an indeterminate `ProgressView` if
  the transfer size is unknown.
- SF Symbols used: `headphones`, `arrow.counterclockwise`, `checkmark`, `xmark`,
  `arrow.down`, `arrow.uturn.backward`, `play.fill`, `minus.circle`.

### Training flow (`RSRTrainingComponents` / `TrainingFlowView`)

- Drive everything from one `RSRTrainingState`:
  `.inProgress(phase:fraction:etaText:)` or `.complete`. The sheet and the bar
  both read it, so flipping to `.complete` updates the chip, numerals, bar,
  steps, and footer together.
- **The sheet stays mounted** across in-progress → complete (don't dismiss it on
  completion). Footer swaps from `Leave running` + `Cancel training` to a single
  **`Install model`** button + `Done`.
- **`Leave running` collapses, it doesn't close.** Drop an `RSRTrainingBar` into
  the Start-training button slot and stamp `.rsrTabBadge(.running, …)` on the
  Train tab. On completion the bar turns green ("New model ready") and the badge
  flips to `.ready` (also surface it on the Models tab); once installed, swap the
  bar back for the `Start training` button.
- **Don't silently retitle the data card.** The label-breakdown box keeps one
  state-agnostic title ("Training data") in both idle and running states.
- `RSRTrainingProgressBar` is the single source of progress — same bar in the
  sheet hero and the collapsed bar. `animated:` runs the shimmer while in
  progress; turn it off when complete.
- SF Symbols used: `checkmark`, `chevron.up`, `chevron.right`,
  `square.and.arrow.down`, `waveform`.

_v1.0 — pairs with “Rich Sound Recorder — Design System.dc.html”._
