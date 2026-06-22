//
//  RSRTrainingComponents.swift
//  Rich Sound Recorder — Design System
//
//  Widgets for the "Training in progress" flow: the bottom sheet shown
//  after tapping "Start training", the pinned collapsed bar it leaves
//  behind, the phase stepper, a live pulsing dot, and the tab-bar
//  running/ready badge. Built entirely from the existing RSR tokens.
//
//  Flow:  Start training → RSRTrainingSheet(.inProgress)
//         → "Leave running" collapses to RSRTrainingBar(.running) (pinned
//           in the Start-training slot; a badge appears on the Train tab)
//         → on completion the bar/sheet flip to their .complete state
//         → "Install model" / "Done", and the bar reverts to the button.
//

import SwiftUI

// MARK: - Phases

/// The four server-side phases, in order.
enum RSRTrainingPhase: Int, CaseIterable {
    case uploading, preprocessing, training, packaging
    var title: String {
        switch self {
        case .uploading:     return "Uploading data"
        case .preprocessing: return "Preprocessing"
        case .training:      return "Training model"
        case .packaging:     return "Packaging for device"
        }
    }
}

/// Whole-run state.
enum RSRTrainingState: Equatable {
    case inProgress(phase: RSRTrainingPhase, fraction: Double, etaText: String)
    case complete
}

private extension RSRTrainingPhase {
    /// Step status given the current run state.
    func status(in state: RSRTrainingState) -> RSRStepStatus {
        switch state {
        case .complete: return .done
        case .inProgress(let cur, let frac, _):
            if rawValue < cur.rawValue { return .done }
            if rawValue > cur.rawValue { return .queued }
            return .current(fraction: frac)
        }
    }
}

enum RSRStepStatus: Equatable { case done, current(fraction: Double), queued }

// MARK: - Live pulsing dot

struct RSRLiveDot: View {
    var color: Color = RSR.accent
    var size: CGFloat = 9
    @State private var on = false

    var body: some View {
        Circle().fill(color).frame(width: size, height: size)
            .overlay(
                Circle().stroke(color, lineWidth: 7)
                    .scaleEffect(on ? 1.9 : 1).opacity(on ? 0 : 0.55)
            )
            .animation(.easeOut(duration: 1.8).repeatForever(autoreverses: false), value: on)
            .onAppear { on = true }
    }
}

// MARK: - Progress bar (single, gradient, optional shimmer)

struct RSRTrainingProgressBar: View {
    var fraction: Double
    var height: CGFloat = 8
    var tint: LinearGradient = RSR.accentGradient
    var animated: Bool = true
    @State private var shimmer = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(RSR.trackFill)
                Capsule().fill(tint)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
                    .overlay(alignment: .leading) {
                        if animated {
                            Rectangle()
                                .fill(LinearGradient(colors: [.clear, .white.opacity(0.55), .clear],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: 46)
                                .offset(x: shimmer ? geo.size.width : -46)
                                .animation(.linear(duration: 2.4).repeatForever(autoreverses: false), value: shimmer)
                        }
                    }
                    .clipShape(Capsule())
            }
        }
        .frame(height: height)
        .onAppear { shimmer = true }
    }
}

// MARK: - Phase stepper (connected timeline)

struct RSRTrainingStepper: View {
    let state: RSRTrainingState

    var body: some View {
        VStack(spacing: 0) {
            ForEach(RSRTrainingPhase.allCases, id: \.self) { phase in
                stepRow(phase, isLast: phase == .packaging)
            }
        }
    }

    @ViewBuilder
    private func stepRow(_ phase: RSRTrainingPhase, isLast: Bool) -> some View {
        let status = phase.status(in: state)
        HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 5) {
                node(status)
                if !isLast {
                    Rectangle()
                        .fill(connectorColor(phase))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .clipShape(Capsule())
                }
            }
            .frame(width: 26)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(phase.title)
                        .font(.rsrHeadline)
                        .foregroundStyle(status == .queued ? RSR.labelTertiary : RSR.labelPrimary)
                    Spacer()
                    Text(trailing(status)).font(.rsrSubhead.weight(.semibold)).foregroundStyle(trailingColor(status))
                }
                .frame(minHeight: 26)
                if case .current = status {
                    Text("Building the acoustic model")
                        .font(.rsrSubhead).foregroundStyle(RSR.labelTertiary)
                }
            }
            .padding(.bottom, isLast ? 0 : 18)
        }
    }

    // Node circle per status
    @ViewBuilder private func node(_ status: RSRStepStatus) -> some View {
        switch status {
        case .done:
            Circle().fill(RSR.success).frame(width: 26, height: 26)
                .overlay(Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white))
                .shadow(color: RSR.success.opacity(0.4), radius: 4, y: 2)
        case .current:
            Circle().fill(RSR.accentGradient).frame(width: 26, height: 26)
                .overlay(Circle().fill(.white).frame(width: 9, height: 9))
                .overlay(Circle().stroke(RSR.accent.opacity(0.4), lineWidth: 1).scaleEffect(1.5))
                .shadow(color: RSR.accent.opacity(0.45), radius: 6, y: 2)
        case .queued:
            Circle().strokeBorder(RSR.trackFill, lineWidth: 2).frame(width: 26, height: 26)
        }
    }

    private func connectorColor(_ phase: RSRTrainingPhase) -> Color {
        switch phase.status(in: state) {
        case .done:    return RSR.success
        default:       return RSR.trackFill
        }
    }
    private func trailing(_ s: RSRStepStatus) -> String {
        switch s {
        case .done: return "Done"
        case .current(let f): return "\(Int(f * 100))%"
        case .queued: return "Queued"
        }
    }
    private func trailingColor(_ s: RSRStepStatus) -> Color {
        switch s {
        case .done: return RSR.success
        case .current: return RSR.accent
        case .queued: return RSR.labelTertiary
        }
    }
}

// MARK: - Status chip (header of the sheet)

private struct RSRTrainingChip: View {
    let state: RSRTrainingState
    var body: some View {
        HStack(spacing: state.isComplete ? 6 : 7) {
            if state.isComplete {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(RSR.success)
            } else {
                RSRLiveDot(size: 8)
            }
            Text(state.isComplete ? "Completed" : "In progress")
                .font(.rsrCaption).foregroundStyle(state.isComplete ? RSR.success : RSR.accent)
        }
        .padding(.vertical, 7).padding(.leading, state.isComplete ? 10 : 11).padding(.trailing, 12)
        .background((state.isComplete ? RSR.success : RSR.accent).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: RSRRadius.chip, style: .continuous))
    }
}

private extension RSRTrainingState {
    var isComplete: Bool { if case .complete = self { return true }; return false }
    var fraction: Double { if case .inProgress(_, let f, _) = self { return f }; return 1 }
    var etaText: String { if case .inProgress(_, _, let e) = self { return e }; return "Completed just now" }
}

// MARK: - Training sheet
//
// The bottom sheet. Stays mounted across .inProgress → .complete; only
// the chip, numerals, bar, steps, and the footer buttons change.

struct RSRTrainingSheet: View {
    let state: RSRTrainingState
    var project: String = "Compressor Line A"
    var clipCount: Int = 48
    var onLeaveRunning: () -> Void = {}
    var onCancel: () -> Void = {}
    var onInstall: () -> Void = {}
    var onDone: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(RSR.hairline).frame(width: 38, height: 5).padding(.top, 10)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Training model").font(.rsrTitle).foregroundStyle(RSR.labelPrimary)
                    Text("\(project) · \(clipCount) clips").font(.rsrSubhead).foregroundStyle(RSR.labelSecondary)
                }
                Spacer()
                RSRTrainingChip(state: state)
            }
            .padding(.top, 20)

            HStack(alignment: .bottom, spacing: 12) {
                Text("\(Int(state.fraction * 100))%")
                    .font(.system(size: 46, weight: .ultraLight)).foregroundStyle(RSR.labelPrimary).monospacedDigit()
                Text(state.etaText).font(.rsrBody).foregroundStyle(RSR.labelSecondary).padding(.bottom, 7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 24)

            RSRTrainingProgressBar(
                fraction: state.fraction,
                tint: state.isComplete
                    ? LinearGradient(colors: [RSR.success, Color(hex: 0x28B14A)], startPoint: .leading, endPoint: .trailing)
                    : RSR.accentGradient,
                animated: !state.isComplete
            )
            .padding(.top, 14)

            RSRTrainingStepper(state: state).padding(.top, 28)

            Spacer(minLength: 8)

            Text(state.isComplete
                 ? "Your model is ready — training finished. Install it from Models, or close this any time."
                 : "Training continues in the cloud if you leave — come back to Train any time to check progress.")
                .font(.rsrSubhead).foregroundStyle(RSR.labelTertiary)
                .multilineTextAlignment(.center).padding(.horizontal, 6)

            footer.padding(.top, 16)
            Spacer().frame(height: 14)
        }
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(RSR.surfaceGlassStrong)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    @ViewBuilder private var footer: some View {
        if state.isComplete {
            VStack(spacing: 0) {
                Button(action: onInstall) {
                    HStack(spacing: 9) {
                        Image(systemName: "square.and.arrow.down").font(.system(size: 17, weight: .semibold))
                        Text("Install model").font(.rsrHeadline)
                    }
                    .foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 56)
                    .background(RSR.accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: RSRRadius.control, style: .continuous))
                    .rsrShadow(.accentLift)
                }.buttonStyle(.plain)
                Button(action: onDone) {
                    Text("Done").font(.rsrHeadline).foregroundStyle(RSR.accent).frame(height: 48)
                }.buttonStyle(.plain)
            }
        } else {
            VStack(spacing: 0) {
                RSRPrimaryButton(title: "Leave running", action: onLeaveRunning)
                Button(action: onCancel) {
                    Text("Cancel training").font(.rsrBody.weight(.semibold)).foregroundStyle(RSR.danger).frame(height: 48)
                }.buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Collapsed bar
//
// What "Leave running" leaves behind — pinned in the Start-training slot.
// Tap to re-open the sheet. Flips to a green "Training complete" treatment
// that bridges to install.

struct RSRTrainingBar: View {
    let state: RSRTrainingState
    var onTap: () -> Void = {}

    var body: some View {
        let done = state.isComplete
        let tint: Color = done ? RSR.success : RSR.accent
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    if done {
                        Circle().fill(RSR.success).frame(width: 20, height: 20)
                            .overlay(Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white))
                    } else {
                        RSRLiveDot(size: 9)
                    }
                    Text(done ? "Training complete" : "Training model")
                        .font(.rsrBody.weight(.bold)).foregroundStyle(RSR.labelPrimary)
                    Spacer()
                    Text("\(Int(state.fraction * 100))%")
                        .font(.rsrBody.weight(.bold)).foregroundStyle(tint).monospacedDigit()
                    Image(systemName: done ? "chevron.right" : "chevron.up")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(tint.opacity(0.7))
                }
                RSRTrainingProgressBar(
                    fraction: state.fraction, height: 6,
                    tint: done
                        ? LinearGradient(colors: [RSR.success, Color(hex: 0x28B14A)], startPoint: .leading, endPoint: .trailing)
                        : RSR.accentGradient,
                    animated: !done
                ).padding(.top, 12)
                HStack {
                    Text(done ? "New model ready · tap to install" : "\(state.etaText) · continues in the cloud")
                        .font(.rsrSubhead).foregroundStyle(RSR.labelSecondary)
                    Spacer()
                }
                .padding(.top, 10)
            }
            .padding(15)
            .background(tint.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: RSRRadius.control, style: .continuous).strokeBorder(tint.opacity(0.3), lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: RSRRadius.control, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tab-bar badge
//
// A small dot stamped on a tab icon: pulsing accent while running, solid
// green when a model is ready. `ringColor` should match the tab-bar fill
// so the badge reads as cut out of the bar.

extension View {
    func rsrTabBadge(_ kind: RSRBadgeKind, ringColor: Color) -> some View {
        overlay(alignment: .topTrailing) {
            Group {
                switch kind {
                case .none: EmptyView()
                case .running:
                    RSRLiveDot(color: RSR.accent, size: 7)
                        .padding(2).background(ringColor).clipShape(Circle())
                case .ready:
                    Circle().fill(RSR.success).frame(width: 7, height: 7)
                        .padding(2).background(ringColor).clipShape(Circle())
                }
            }
            .offset(x: 5, y: -3)
        }
    }
}

enum RSRBadgeKind { case none, running, ready }
