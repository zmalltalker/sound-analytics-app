//
//  DetectView.swift
//  Rich Sound Recorder — Design System · Example
//
//  Reference assembly: the Detect "results" screen built entirely from
//  RSR widgets and tokens. Shows how the pieces compose and how the
//  appearance inverts for free (preview includes light + dark).
//

import SwiftUI

struct DetectView: View {
    @State private var selectedTab = 1   // Detect

    var body: some View {
        ZStack(alignment: .bottom) {
            RSR.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: RSRSpace.md) {

                    // Top app bar: title + compact project chip
                    HStack {
                        Text("Detect")
                            .font(.rsrLargeTitle)
                            .tracking(RSRTracking.largeTitle)
                            .foregroundStyle(RSR.labelPrimary)
                        Spacer()
                        RSRProjectChip(name: "Compressor Line A")
                    }
                    .padding(.top, 8)

                    // Capture review card with inline waveform
                    RSRCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Capture · 0:14").font(.rsrBody.weight(.semibold))
                                    .foregroundStyle(RSR.labelPrimary)
                                Spacer()
                                Text("Model v3").font(.rsrSubhead).foregroundStyle(RSR.labelSecondary)
                            }
                            RSRWaveform(count: 60, amplitude: 64, barWidth: 2.4, gap: 2.1,
                                        seed: 4, color: RSR.accent.opacity(0.9))
                                .frame(height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }

                    Text("3 events detected").font(.rsrHeadline).foregroundStyle(RSR.labelPrimary)

                    RSREventCard(name: "Bearing fault", timeRange: "0:03.2 – 0:05.1",
                                 confidence: 0.94)
                    RSREventCard(name: "Cavitation", timeRange: "0:08.0 – 0:09.4",
                                 confidence: 0.78)
                    RSREventCard(name: "Normal run", timeRange: "0:11.6 – 0:14.0",
                                 confidence: 0.61, isPrimary: false)

                    RSRPrimaryButton(title: "Run again")
                        .padding(.top, 2)
                }
                .padding(.horizontal, RSRSpace.screen)
                .padding(.bottom, 120)   // clear the floating tab bar
            }

            RSRTabBar(tabs: RSRTabBar.standardTabs, selection: $selectedTab)
                .padding(.bottom, 8)
        }
    }
}

#Preview("Light") {
    DetectView().preferredColorScheme(.light)
}

#Preview("Dark") {
    DetectView().preferredColorScheme(.dark)
}
