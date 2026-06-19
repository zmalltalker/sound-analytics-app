import SwiftUI

struct DesignSystemShowcaseView: View {
    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RSRSpace.lg) {
                headerSection
                buttonSection
                selectorSection
                waveformSection
                reviewSection
                labelsSection
                eventsSection
                tabBarSection
                typographySection
            }
            .padding(.horizontal, RSRSpace.screen)
            .padding(.top, RSRSpace.card)
            .padding(.bottom, RSRSpace.lg)
        }
        .background(RSR.canvas.ignoresSafeArea())
        .navigationTitle("Design system")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        RSRCard {
            VStack(alignment: .leading, spacing: RSRSpace.sm) {
                Text("Rich Sound Recorder")
                    .font(.rsrLargeTitle)
                    .tracking(RSRTracking.largeTitle)
                    .foregroundStyle(RSR.labelPrimary)

                Text("Semantic tokens, glass surfaces, and reusable widgets shown with static content.")
                    .font(.rsrSubhead)
                    .foregroundStyle(RSR.labelSecondary)
            }
        }
    }

    private var buttonSection: some View {
        VStack(alignment: .leading, spacing: RSRSpace.md) {
            sectionTitle("Buttons")

            RSRPrimaryButton(title: "Start training")
            RSRSecondaryButton(title: "Record audio", showsRecordDot: true)
            

            HStack {
                RSRTonalButton(title: "Switch")
                RSRTonalButton(title: "Manage")
                Spacer()
            }
        }
    }

    private var selectorSection: some View {
        VStack(alignment: .leading, spacing: RSRSpace.md) {
            sectionTitle("Selectors")

            RSRProjectSelector(name: "Compressor Line A")
            RSRProjectChip(name: "Compressor Line A")

            RSRListRow(
                title: "Model v12",
                subtitle: "Default · 4 labels · on device",
                systemImage: "square.stack.3d.up"
            )
        }
    }

    private var waveformSection: some View {
        VStack(alignment: .leading, spacing: RSRSpace.md) {
            sectionTitle("Waveforms")

            RSRCard {
                VStack(alignment: .leading, spacing: RSRSpace.card) {
                    Text("Live")
                        .font(.rsrCaption)
                        .tracking(RSRTracking.eyebrow)
                        .foregroundStyle(RSR.accent)

                    RSRWaveform.hero
                        .frame(height: 160)

                    Divider()
                        .overlay(RSR.hairline)

                    Text("Passive")
                        .font(.rsrCaption)
                        .tracking(RSRTracking.eyebrow)
                        .foregroundStyle(RSR.labelSecondary)

                    RSRWaveform.muted
                        .frame(height: 96)
                }
            }
        }
    }

    private var labelsSection: some View {
        VStack(alignment: .leading, spacing: RSRSpace.md) {
            sectionTitle("Readiness")

            RSRCard {
                VStack(alignment: .leading, spacing: RSRSpace.md) {
                    Text("Ready to train")
                        .font(.rsrTitle)
                        .tracking(RSRTracking.title)
                        .foregroundStyle(RSR.labelPrimary)

                    Text("3 of 4 labels have audio · 48 clips")
                        .font(.rsrSubhead)
                        .foregroundStyle(RSR.labelSecondary)

                    Divider()
                        .overlay(RSR.hairline)

                    VStack(spacing: RSRSpace.sm) {
                        RSRLabelRow(name: "Bearing fault", state: .ready(clips: 24, fraction: 1.0))
                        RSRLabelRow(name: "Normal run", state: .ready(clips: 18, fraction: 0.75))
                        RSRLabelRow(name: "Cavitation", state: .ready(clips: 6, fraction: 0.3))
                        RSRLabelRow(name: "Impeller wear", state: .needsAudio)
                    }
                }
            }
        }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: RSRSpace.md) {
            sectionTitle("Review")

            RSRCard {
                VStack(alignment: .leading, spacing: RSRSpace.card) {
                    Text("In-session review")
                        .font(.rsrTitle)
                        .tracking(RSRTracking.title)
                        .foregroundStyle(RSR.labelPrimary)

                    RSRReviewProgressHeader(index: 3, total: 12)

                    Text("Recorded Jun 13, 4:47 PM")
                        .font(.rsrSubhead)
                        .foregroundStyle(RSR.labelSecondary)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .rsrGlass(.thin, radius: 14, elevation: .resting)

                    HStack(alignment: .bottom, spacing: 10) {
                        Text("0:13")
                            .font(.rsrDisplay)
                            .foregroundStyle(RSR.labelPrimary)
                            .monospacedDigit()

                        Text("/ 0:21")
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(RSR.labelTertiary)
                            .padding(.bottom, 12)
                    }

                    HStack(spacing: 7) {
                        HStack(alignment: .bottom, spacing: 2) {
                            reviewActivityBar(6)
                            reviewActivityBar(12)
                            reviewActivityBar(8)
                        }
                        .frame(height: 12)

                        Text("PLAYING")
                            .font(.rsrCaption)
                            .tracking(0.6)
                            .foregroundStyle(RSR.accent.opacity(0.85))
                    }

                    RSRReviewWaveform(seed: 9, progress: 0.62)
                        .frame(height: 124)

                    HStack {
                        Text("0:13")
                            .font(.rsrCaption)
                            .foregroundStyle(RSR.labelSecondary)
                            .monospacedDigit()
                        Spacer()
                        Text("0:21")
                            .font(.rsrCaption)
                            .foregroundStyle(RSR.labelTertiary)
                            .monospacedDigit()
                    }

                    HStack {
                        RSRReplayButton()
                        Spacer()
                    }

                    RSRDecisionBar()

                    Text("Kept 2 · Removed 0")
                        .font(.rsrCaption)
                        .foregroundStyle(RSR.labelTertiary)
                        .monospacedDigit()
                }
            }

            RSRCard {
                VStack(alignment: .leading, spacing: RSRSpace.card) {
                    Text("Pre-flight")
                        .font(.rsrTitle)
                        .tracking(RSRTracking.title)
                        .foregroundStyle(RSR.labelPrimary)

                    RSRHeadphonesPrompt(count: 12, totalLength: "~8 min total")
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            RSRCard {
                VStack(alignment: .leading, spacing: RSRSpace.card) {
                    Text("Loading and outcome")
                        .font(.rsrTitle)
                        .tracking(RSRTracking.title)
                        .foregroundStyle(RSR.labelPrimary)

                    HStack(alignment: .center, spacing: RSRSpace.card) {
                        VStack(spacing: RSRSpace.md) {
                            RSRDownloadRing(progress: 0.72, size: 72)
                            Text("Loading")
                                .font(.rsrSubhead.weight(.semibold))
                                .foregroundStyle(RSR.labelSecondary)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: RSRSpace.md) {
                            RSROutcomeBadge(outcome: .kept)
                                .frame(maxWidth: .infinity)
                            Text("Kept")
                                .font(.rsrSubhead.weight(.semibold))
                                .foregroundStyle(RSR.success)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func reviewActivityBar(_ height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(RSR.accent)
            .frame(width: 3, height: height)
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: RSRSpace.md) {
            sectionTitle("Detection events")

            VStack(spacing: RSRSpace.sm) {
                RSREventCard(name: "Bearing fault", timeRange: "0:04 - 0:07", confidence: 0.94)
                RSREventCard(name: "Normal run", timeRange: "0:11 - 0:13", confidence: 0.61, isPrimary: false)
            }
        }
    }

    private var tabBarSection: some View {
        VStack(alignment: .leading, spacing: RSRSpace.md) {
            sectionTitle("Navigation")
            RSRTabBar(tabs: RSRTabBar.standardTabs, selection: $selectedTab)
        }
    }

    private var typographySection: some View {
        VStack(alignment: .leading, spacing: RSRSpace.md) {
            sectionTitle("Typography")
            Text("rsrDisplay")
                .font(.rsrDisplay)
            Text("rsrLargeTitle").font(.rsrLargeTitle)
            Text("rsrTitle").font(.rsrTitle)
            Text("rsrHeadline").font(.rsrHeadline)
            Text("rsrBody").font(.rsrBody)
            Text("rsrSubhead").font(.rsrSubhead)
            Text("rsrCaption").font(.rsrCaption)
            Text("rsrMeta").font(.rsrMeta)
            Text("rsrEyebrow").rsrEyebrow()
            Text("rsrTabular").rsrTabular()
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.rsrCaption)
            .tracking(RSRTracking.eyebrow)
            .foregroundStyle(RSR.labelSecondary)
    }
}

struct DesignSystemShowcaseView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationStack {
                DesignSystemShowcaseView()
            }
            .preferredColorScheme(.light)

            NavigationStack {
                DesignSystemShowcaseView()
            }
            .preferredColorScheme(.dark)
        }
    }
}
