//
//  TrainingFlowView.swift
//  Rich Sound Recorder — Design System · Example
//
//  Reference assembly of the "Training in progress" flow, built from the
//  RSR* widgets + RSRTraining* widgets. Shows the sheet (in-progress and
//  complete) presented over the Train screen, and the Train screen itself
//  with the collapsed bar pinned in the Start-training slot.
//

import SwiftUI

// MARK: - Train screen with the collapsed bar pinned

struct TrainingCollapsedView: View {
    /// Pass .complete to show the green "ready to install" treatment.
    let state: RSRTrainingState

    private var badge: RSRBadgeKind { state.isCompletePublic ? .ready : .running }

    var body: some View {
        ZStack(alignment: .bottom) {
            RSR.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Train").font(.rsrLargeTitle).foregroundStyle(RSR.labelPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)

                    projectPill

                    RSRCard {
                        VStack(spacing: 0) {
                            // State-agnostic title — same box whether idle or training.
                            HStack(spacing: 13) {
                                Circle().fill(RSR.success.opacity(0.16)).frame(width: 42, height: 42)
                                    .overlay(Image(systemName: "checkmark").font(.system(size: 20, weight: .semibold)).foregroundStyle(RSR.success))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Training data").font(.rsrTitle).foregroundStyle(RSR.labelPrimary)
                                    Text("3 of 4 labels have audio · 48 clips").font(.rsrSubhead).foregroundStyle(RSR.labelSecondary)
                                }
                                Spacer()
                            }
                            Divider().overlay(RSR.hairline).padding(.vertical, 14)
                            labelRow("Bearing fault", fraction: 1.0, count: "24")
                            labelRow("Normal run", fraction: 0.75, count: "18")
                            labelRow("Cavitation", fraction: 0.26, count: "6")
                            labelRowNeedsAudio("Impeller wear")
                        }
                    }

                    // The bar sits where "Start training" was while a run is active.
                    RSRTrainingBar(state: state)

                    RSRSecondaryButton(title: "Record audio", showsRecordDot: true)
                }
                .padding(.horizontal, RSRSpace.screen)
                .padding(.bottom, 120)
            }

            tabBar
        }
    }

    private var projectPill: some View {
        HStack {
            HStack(spacing: 11) {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(RSR.accentTileGradient)
                    .frame(width: 34, height: 34)
                    .overlay(Image(systemName: "waveform").font(.system(size: 15, weight: .bold)).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Compressor Line A").font(.rsrBody.weight(.semibold)).foregroundStyle(RSR.labelPrimary)
                    Text("Active project").font(.system(size: 12, weight: .medium)).foregroundStyle(RSR.labelSecondary)
                }
            }
            Spacer()
            RSRTonalButton(title: "Switch")
        }
        .padding(.leading, 14).padding(.trailing, 12).padding(.vertical, 10)
        .rsrGlass(.regular, radius: RSRRadius.control, elevation: .resting)
    }

    private func labelRow(_ name: String, fraction: Double, count: String) -> some View {
        HStack(spacing: 12) {
            Circle().fill(RSR.success).frame(width: 8, height: 8)
            Text(name).font(.rsrBody.weight(.semibold)).foregroundStyle(RSR.labelPrimary)
            Spacer()
            RSRMeter(fraction: fraction).frame(width: 64, height: 6)
            Text(count).font(.rsrSubhead.weight(.semibold)).foregroundStyle(RSR.labelSecondary).frame(width: 30, alignment: .trailing)
        }
        .padding(.vertical, 9)
    }
    private func labelRowNeedsAudio(_ name: String) -> some View {
        HStack(spacing: 12) {
            Circle().fill(RSR.warning).frame(width: 8, height: 8)
            Text(name).font(.rsrBody.weight(.semibold)).foregroundStyle(RSR.labelPrimary)
            Spacer()
            Text("Needs audio").font(.rsrSubhead.weight(.semibold)).foregroundStyle(RSR.warning)
        }
        .padding(.vertical, 9)
    }

    private var tabBar: some View {
        HStack {
            tabItem("waveform", "Train", selected: true).rsrTabBadge(badge, ringColor: RSR.surfaceTabBar)
            tabItem("scope", "Detect")
            tabItem("square.stack.3d.up", "Models").rsrTabBadge(state.isCompletePublic ? .ready : .none, ringColor: RSR.surfaceTabBar)
            tabItem("slider.horizontal.3", "Settings")
        }
        .padding(.horizontal, 8).frame(height: 66)
        .rsrGlass(.thick, radius: RSRRadius.tabBar, elevation: .floating)
        .padding(.horizontal, 14).padding(.bottom, 18)
    }
    private func tabItem(_ symbol: String, _ label: String, selected: Bool = false) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 20, weight: selected ? .semibold : .regular))
            Text(label).font(.rsrCaption)
        }
        .foregroundStyle(selected ? RSR.accent : RSR.labelSecondary)
        .frame(maxWidth: .infinity)
    }
}

private extension RSRTrainingState {
    // local mirror so the example can branch without touching the component file
    var isCompletePublic: Bool { if case .complete = self { return true }; return false }
}

// MARK: - Sheet presented over the Train screen

struct TrainingSheetScreen: View {
    let state: RSRTrainingState
    var body: some View {
        ZStack(alignment: .bottom) {
            TrainingCollapsedView(state: .inProgress(phase: .training, fraction: 0.62, etaText: "~4 min remaining"))
                .disabled(true)
            Color.black.opacity(0.34).ignoresSafeArea()
            RSRTrainingSheet(state: state)
                .frame(maxHeight: 652)
        }
    }
}

// MARK: - Previews

#Preview("Sheet · In progress · Light") {
    TrainingSheetScreen(state: .inProgress(phase: .training, fraction: 0.62, etaText: "~4 min remaining"))
        .preferredColorScheme(.light)
}
#Preview("Sheet · In progress · Dark") {
    TrainingSheetScreen(state: .inProgress(phase: .training, fraction: 0.62, etaText: "~4 min remaining"))
        .preferredColorScheme(.dark)
}
#Preview("Sheet · Complete · Light") {
    TrainingSheetScreen(state: .complete).preferredColorScheme(.light)
}
#Preview("Sheet · Complete · Dark") {
    TrainingSheetScreen(state: .complete).preferredColorScheme(.dark)
}
#Preview("Bar · Running · Light") {
    TrainingCollapsedView(state: .inProgress(phase: .training, fraction: 0.62, etaText: "~4 min remaining"))
        .preferredColorScheme(.light)
}
#Preview("Bar · Complete · Dark") {
    TrainingCollapsedView(state: .complete).preferredColorScheme(.dark)
}
