import SwiftUI

enum RSRTrainingPhase: Int, CaseIterable {
    case uploading
    case preprocessing
    case training
    case packaging

    var title: String {
        switch self {
        case .uploading:
            return "Uploading data"
        case .preprocessing:
            return "Preprocessing"
        case .training:
            return "Training model"
        case .packaging:
            return "Packaging for device"
        }
    }
}

enum RSRTrainingState: Equatable {
    case inProgress(phase: RSRTrainingPhase, fraction: Double, etaText: String)
    case complete
}

enum RSRStepStatus: Equatable {
    case done
    case current(fraction: Double)
    case queued
}

enum RSRBadgeKind {
    case none
    case running
    case ready
}

private extension RSRTrainingPhase {
    func status(in state: RSRTrainingState) -> RSRStepStatus {
        switch state {
        case .complete:
            return .done
        case .inProgress(let currentPhase, let fraction, _):
            if rawValue < currentPhase.rawValue {
                return .done
            }
            if rawValue > currentPhase.rawValue {
                return .queued
            }
            return .current(fraction: fraction)
        }
    }
}

private extension RSRTrainingState {
    var isComplete: Bool {
        if case .complete = self { return true }
        return false
    }

    var fraction: Double {
        if case .inProgress(_, let fraction, _) = self {
            return fraction
        }
        return 1
    }

    var etaText: String {
        if case .inProgress(_, _, let etaText) = self {
            return etaText
        }
        return "Completed just now"
    }
}

struct RSRLiveDot: View {
    var color: Color = RSR.accent
    var size: CGFloat = 9

    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .stroke(color, lineWidth: 7)
                    .scaleEffect(isAnimating ? 1.9 : 1)
                    .opacity(isAnimating ? 0 : 0.55)
            }
            .animation(.easeOut(duration: 1.8).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

struct RSRTrainingProgressBar: View {
    var fraction: Double
    var height: CGFloat = 8
    var tint: LinearGradient = RSR.accentGradient
    var animated = true

    @State private var shimmer = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(RSR.trackFill)

                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, fraction)) * geometry.size.width)
                    .overlay(alignment: .leading) {
                        if animated {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, .white.opacity(0.55), .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 46)
                                .offset(x: shimmer ? geometry.size.width : -46)
                                .animation(.linear(duration: 2.4).repeatForever(autoreverses: false), value: shimmer)
                        }
                    }
                    .clipShape(Capsule())
            }
        }
        .frame(height: height)
        .onAppear {
            shimmer = true
        }
    }
}

struct RSRTrainingStepper: View {
    let state: RSRTrainingState

    var body: some View {
        VStack(spacing: 0) {
            ForEach(RSRTrainingPhase.allCases, id: \.self) { phase in
                row(for: phase, isLast: phase == .packaging)
            }
        }
    }

    private func row(for phase: RSRTrainingPhase, isLast: Bool) -> some View {
        let status = phase.status(in: state)

        return HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 5) {
                node(for: status)
                if !isLast {
                    Rectangle()
                        .fill(connectorColor(for: phase))
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

                    Text(trailingText(for: status))
                        .font(.rsrSubhead.weight(.semibold))
                        .foregroundStyle(trailingColor(for: status))
                }
                .frame(minHeight: 26)

                if case .current = status {
                    Text(phase == .packaging ? "Finalizing the device-ready archive" : "Building the acoustic model")
                        .font(.rsrSubhead)
                        .foregroundStyle(RSR.labelTertiary)
                }
            }
            .padding(.bottom, isLast ? 0 : 18)
        }
    }

    @ViewBuilder
    private func node(for status: RSRStepStatus) -> some View {
        switch status {
        case .done:
            Circle()
                .fill(RSR.success)
                .frame(width: 26, height: 26)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                .shadow(color: RSR.success.opacity(0.4), radius: 4, y: 2)
        case .current:
            Circle()
                .fill(RSR.accentGradient)
                .frame(width: 26, height: 26)
                .overlay {
                    Circle()
                        .fill(.white)
                        .frame(width: 9, height: 9)
                }
                .overlay {
                    Circle()
                        .stroke(RSR.accent.opacity(0.4), lineWidth: 1)
                        .scaleEffect(1.5)
                }
                .shadow(color: RSR.accent.opacity(0.45), radius: 6, y: 2)
        case .queued:
            Circle()
                .strokeBorder(RSR.trackFill, lineWidth: 2)
                .frame(width: 26, height: 26)
        }
    }

    private func connectorColor(for phase: RSRTrainingPhase) -> Color {
        switch phase.status(in: state) {
        case .done:
            return RSR.success
        default:
            return RSR.trackFill
        }
    }

    private func trailingText(for status: RSRStepStatus) -> String {
        switch status {
        case .done:
            return "Done"
        case .current(let fraction):
            return "\(Int(fraction * 100))%"
        case .queued:
            return "Queued"
        }
    }

    private func trailingColor(for status: RSRStepStatus) -> Color {
        switch status {
        case .done:
            return RSR.success
        case .current:
            return RSR.accent
        case .queued:
            return RSR.labelTertiary
        }
    }
}

private struct RSRTrainingChip: View {
    let state: RSRTrainingState

    var body: some View {
        HStack(spacing: state.isComplete ? 6 : 7) {
            if state.isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(RSR.success)
            } else {
                RSRLiveDot(size: 8)
            }

            Text(state.isComplete ? "Completed" : "In progress")
                .font(.rsrCaption)
                .foregroundStyle(state.isComplete ? RSR.success : RSR.accent)
        }
        .padding(.vertical, 7)
        .padding(.leading, state.isComplete ? 10 : 11)
        .padding(.trailing, 12)
        .background((state.isComplete ? RSR.success : RSR.accent).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: RSRRadius.chip, style: .continuous))
    }
}

struct RSRTrainingSheet: View {
    let state: RSRTrainingState
    var project = "Compressor Line A"
    var clipCount = 48
    var isInstalling = false
    var onLeaveRunning: () -> Void = {}
    var onCancel: () -> Void = {}
    var onInstall: () -> Void = {}
    var onDone: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(RSR.hairline)
                .frame(width: 38, height: 5)
                .padding(.top, 10)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Training model")
                        .font(.rsrTitle)
                        .foregroundStyle(RSR.labelPrimary)

                    Text("\(project) · \(clipCount) clips")
                        .font(.rsrSubhead)
                        .foregroundStyle(RSR.labelSecondary)
                }

                Spacer()

                RSRTrainingChip(state: state)
            }
            .padding(.top, 20)

            HStack(alignment: .bottom, spacing: 12) {
                Text("\(Int(state.fraction * 100))%")
                    .font(.system(size: 46, weight: .ultraLight))
                    .foregroundStyle(RSR.labelPrimary)
                    .monospacedDigit()

                Text(state.etaText)
                    .font(.rsrBody)
                    .foregroundStyle(RSR.labelSecondary)
                    .padding(.bottom, 7)
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

            RSRTrainingStepper(state: state)
                .padding(.top, 28)

            Spacer(minLength: 8)

            Text(
                state.isComplete
                    ? "Your model is ready. Install it from here, or close this and come back from Models later."
                    : "Training continues in the cloud if you leave. Come back to Train any time to check progress."
            )
            .font(.rsrSubhead)
            .foregroundStyle(RSR.labelTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 6)

            footer
                .padding(.top, 16)

            Spacer()
                .frame(height: 14)
        }
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(RSR.surfaceGlassStrong)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    @ViewBuilder
    private var footer: some View {
        if state.isComplete {
            VStack(spacing: 0) {
                Button(action: onInstall) {
                    HStack(spacing: 9) {
                        if isInstalling {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        Text(isInstalling ? "Installing model..." : "Install model")
                            .font(.rsrHeadline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(RSR.accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: RSRRadius.control, style: .continuous))
                    .rsrShadow(.accentLift)
                }
                .buttonStyle(.plain)
                .disabled(isInstalling)

                Button(action: onDone) {
                    Text("Done")
                        .font(.rsrHeadline)
                        .foregroundStyle(RSR.accent)
                        .frame(height: 48)
                }
                .buttonStyle(.plain)
                .disabled(isInstalling)
            }
        } else {
            VStack(spacing: 0) {
                RSRPrimaryButton(title: "Leave running", action: onLeaveRunning)
                Button(action: onCancel) {
                    Text("Cancel training")
                        .font(.rsrBody.weight(.semibold))
                        .foregroundStyle(RSR.danger)
                        .frame(height: 48)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct RSRTrainingBar: View {
    let state: RSRTrainingState
    var onTap: () -> Void = {}

    var body: some View {
        let isComplete = state.isComplete
        let tint = isComplete ? RSR.success : RSR.accent

        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    if isComplete {
                        Circle()
                            .fill(RSR.success)
                            .frame(width: 20, height: 20)
                            .overlay {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                    } else {
                        RSRLiveDot(size: 9)
                    }

                    Text(isComplete ? "Training complete" : "Training model")
                        .font(.rsrBody.weight(.bold))
                        .foregroundStyle(RSR.labelPrimary)

                    Spacer()

                    Text("\(Int(state.fraction * 100))%")
                        .font(.rsrBody.weight(.bold))
                        .foregroundStyle(tint)
                        .monospacedDigit()

                    Image(systemName: isComplete ? "chevron.right" : "chevron.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint.opacity(0.7))
                }

                RSRTrainingProgressBar(
                    fraction: state.fraction,
                    height: 6,
                    tint: isComplete
                        ? LinearGradient(colors: [RSR.success, Color(hex: 0x28B14A)], startPoint: .leading, endPoint: .trailing)
                        : RSR.accentGradient,
                    animated: !isComplete
                )
                .padding(.top, 12)

                HStack {
                    Text(isComplete ? "New model ready · tap to install" : "\(state.etaText) · continues in the cloud")
                        .font(.rsrSubhead)
                        .foregroundStyle(RSR.labelSecondary)
                    Spacer()
                }
                .padding(.top, 10)
            }
            .padding(15)
            .background(tint.opacity(0.08))
            .overlay {
                RoundedRectangle(cornerRadius: RSRRadius.control, style: .continuous)
                    .strokeBorder(tint.opacity(0.3), lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: RSRRadius.control, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func rsrTabBadge(_ kind: RSRBadgeKind, ringColor: Color) -> some View {
        overlay(alignment: .topTrailing) {
            Group {
                switch kind {
                case .none:
                    EmptyView()
                case .running:
                    RSRLiveDot(color: RSR.accent, size: 7)
                        .padding(2)
                        .background(ringColor)
                        .clipShape(Circle())
                case .ready:
                    Circle()
                        .fill(RSR.success)
                        .frame(width: 7, height: 7)
                        .padding(2)
                        .background(ringColor)
                        .clipShape(Circle())
                }
            }
            .offset(x: 5, y: -3)
        }
    }
}
