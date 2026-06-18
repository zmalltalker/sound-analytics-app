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
                labelsSection
                eventsSection
                tabBarSection
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
            sectionTitle("Navigation")
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
