import SwiftUI

// MARK: - Audio Timeline View

/// Waveform + detected-event overlay for one `AudioAnalysisResult`.
///
/// Rendered with SwiftUI `Canvas` so it stays efficient even with thousands of waveform points.
/// Tap a highlighted cyan region to invoke `onEventTapped` with the matching `AudioEventRegion`.
///
/// Wire up `currentTime` from your `AVAudioPlayer` timer to animate the yellow playhead.
struct AudioTimelineView: View {

    /// The analysis result to visualise.
    let result: AudioAnalysisResult

    /// Current playback position in seconds.  Update every ~0.2 s from your player timer.
    var currentTime: TimeInterval = 0

    /// Called when the user taps inside a detected event region.
    var onEventTapped: ((AudioEventRegion) -> Void)?

    var body: some View {
        // Capture into plain local constants so the Canvas closure reads them as value types
        // (avoids any actor-isolation concerns when the Canvas renderer runs).
        let waveform  = result.waveform
        let events    = result.events
        let duration  = result.duration
        let playhead  = currentTime

        GeometryReader { geo in
            Canvas { ctx, size in
                guard duration > 0, size.width > 0 else { return }

                // Converts a time in seconds to an x-coordinate in the canvas.
                func xAt(_ t: TimeInterval) -> CGFloat {
                    CGFloat(t / duration) * size.width
                }

                // ── 1. Event region backgrounds ───────────────────────────────
                for event in events {
                    let x = xAt(event.startTime)
                    let w = max(2, xAt(event.endTime) - x)
                    ctx.fill(
                        Path(CGRect(x: x, y: 0, width: w, height: size.height)),
                        with: .color(.cyan.opacity(0.18))
                    )
                }

                // ── 2. Waveform — symmetric filled shape ──────────────────────
                if waveform.count > 1 {
                    let mid    = size.height / 2
                    let hScale = mid * 0.88   // leave a small top/bottom margin
                    let xStep  = size.width / CGFloat(waveform.count - 1)
                    var path   = Path()

                    // Upper edge (left → right)
                    for (i, pt) in waveform.enumerated() {
                        let p = CGPoint(x: CGFloat(i) * xStep,
                                        y: mid - CGFloat(pt.amplitude) * hScale)
                        i == 0 ? path.move(to: p) : path.addLine(to: p)
                    }
                    // Lower edge (right → left, mirror)
                    for (i, pt) in waveform.enumerated().reversed() {
                        path.addLine(to: CGPoint(x: CGFloat(i) * xStep,
                                                  y: mid + CGFloat(pt.amplitude) * hScale))
                    }
                    path.closeSubpath()

                    ctx.fill(path, with: .color(.white.opacity(0.28)))
                    ctx.stroke(path, with: .color(.white.opacity(0.55)), lineWidth: 0.5)
                }

                // ── 3. Event peak markers (thin vertical lines) ───────────────
                for event in events {
                    let px = xAt(event.peakTime)
                    ctx.stroke(
                        Path { p in
                            p.move(to:    CGPoint(x: px, y: 4))
                            p.addLine(to: CGPoint(x: px, y: size.height - 4))
                        },
                        with: .color(.cyan.opacity(0.85)),
                        lineWidth: 1.5
                    )
                }

                // ── 4. Playhead ───────────────────────────────────────────────
                let clampedPlayhead = min(max(playhead, 0), duration)
                if clampedPlayhead > 0 {
                    let px = xAt(clampedPlayhead)
                    ctx.stroke(
                        Path { p in
                            p.move(to:    CGPoint(x: px, y: 0))
                            p.addLine(to: CGPoint(x: px, y: size.height))
                        },
                        with: .color(.yellow.opacity(0.90)),
                        lineWidth: 2
                    )
                }
            }
            // Tap a region to select the event under the finger
            .gesture(
                DragGesture(minimumDistance: 0).onEnded { drag in
                    guard duration > 0, geo.size.width > 0 else { return }
                    let tappedTime = Double(drag.location.x / geo.size.width) * duration
                    if let hit = events.first(where: {
                        tappedTime >= $0.startTime && tappedTime <= $0.endTime
                    }) {
                        onEventTapped?(hit)
                    }
                }
            )
        }
        .frame(height: 120)
    }
}
