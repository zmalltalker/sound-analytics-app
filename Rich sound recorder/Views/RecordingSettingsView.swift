import SwiftUI
import Combine

@MainActor
final class RecordingSettingsStore: ObservableObject {
    static let shared = RecordingSettingsStore()

    @Published var settings: AudioSettings {
        didSet {
            persist()
        }
    }

    private let defaultsKey = "recording.settings"

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(AudioSettings.self, from: data) {
            settings = decoded
        } else {
            settings = AudioSettings()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

struct RecordingSettingsScreen: View {
    @StateObject private var settingsStore = RecordingSettingsStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RSRSpace.lg) {
                headerSection
                summaryCard
                microphoneSection
                sampleRateSection
                channelsSection
                encodingSection
            }
            .padding(.horizontal, RSRSpace.screen)
            .padding(.top, RSRSpace.card)
            .padding(.bottom, RSRSpace.lg)
        }
        .background(RSR.canvas.ignoresSafeArea())
        .navigationTitle("Recording Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: RSRSpace.xs) {
            Text("Recording settings")
                .font(.rsrLargeTitle)
                .tracking(RSRTracking.largeTitle)
                .foregroundStyle(RSR.labelPrimary)

            Text("These settings apply to all new recordings in training and detection.")
                .font(.rsrSubhead)
                .foregroundStyle(RSR.labelSecondary)
        }
    }

    private var summaryCard: some View {
        RSRCard {
            VStack(alignment: .leading, spacing: RSRSpace.xs) {
                Text("Current profile")
                    .font(.rsrCaption)
                    .tracking(RSRTracking.eyebrow)
                    .foregroundStyle(RSR.labelSecondary)

                Text(settingsStore.settings.summaryText)
                    .font(.rsrMeta)
                    .foregroundStyle(RSR.labelPrimary)
            }
        }
    }

    private var microphoneSection: some View {
        VStack(alignment: .leading, spacing: RSRSpace.md) {
            sectionTitle("Microphone mode")

            VStack(spacing: RSRSpace.sm) {
                ForEach(MicMode.allCases) { mode in
                    MicModeRow(mode: mode, isSelected: settingsStore.settings.micMode == mode) {
                        settingsStore.settings.micMode = mode
                        AppHaptics.stepTick()
                    }
                }
            }
        }
    }

    private var sampleRateSection: some View {
        VStack(alignment: .leading, spacing: RSRSpace.md) {
            sectionTitle("Sample rate")

            RSRCard(radius: RSRRadius.control) {
                VStack(alignment: .leading, spacing: RSRSpace.sm) {
                    ForEach(RecordSampleRate.allCases) { rate in
                        selectableRow(
                            title: rate.label,
                            subtitle: rate.detail,
                            isSelected: settingsStore.settings.sampleRate == rate
                        ) {
                            settingsStore.settings.sampleRate = rate
                            AppHaptics.stepTick()
                        }
                    }

                    Divider()
                        .overlay(RSR.hairline)

                    Text("Nyquist: \(nyquistLabel) · highest reproducible frequency at this rate")
                        .font(.rsrSubhead)
                        .foregroundStyle(RSR.labelSecondary)
                }
            }
        }
    }

    private var channelsSection: some View {
        VStack(alignment: .leading, spacing: RSRSpace.md) {
            sectionTitle("Channels")

            HStack(spacing: RSRSpace.sm) {
                ForEach(RecordChannels.allCases) { channel in
                    chipButton(
                        title: channel.label,
                        isSelected: settingsStore.settings.channels == channel
                    ) {
                        settingsStore.settings.channels = channel
                        AppHaptics.stepTick()
                    }
                }
            }
        }
    }

    private var encodingSection: some View {
        VStack(alignment: .leading, spacing: RSRSpace.md) {
            sectionTitle("Encoding")

            VStack(spacing: RSRSpace.sm) {
                HStack(spacing: RSRSpace.sm) {
                    ForEach(RecordEncoding.allCases) { encoding in
                        chipButton(
                            title: encoding.rawValue,
                            isSelected: settingsStore.settings.encoding == encoding
                        ) {
                            settingsStore.settings.encoding = encoding
                            AppHaptics.stepTick()
                        }
                    }
                }

                RSRCard(radius: RSRRadius.control) {
                    Text(settingsStore.settings.encoding.detail)
                        .font(.rsrSubhead)
                        .foregroundStyle(RSR.labelSecondary)
                }
            }
        }
    }

    private var nyquistLabel: String {
        let hz = settingsStore.settings.sampleRate.nyquist
        return hz >= 1_000 ? "\(Int(hz / 1_000)) kHz" : "\(Int(hz)) Hz"
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.rsrCaption)
            .tracking(RSRTracking.eyebrow)
            .foregroundStyle(RSR.labelSecondary)
            .textCase(.uppercase)
    }

    private func selectableRow(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: RSRSpace.md) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? RSR.accent : RSR.labelTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.rsrBody.weight(.semibold))
                        .foregroundStyle(RSR.labelPrimary)
                    Text(subtitle)
                        .font(.rsrSubhead)
                        .foregroundStyle(RSR.labelSecondary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func chipButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.rsrSubhead.weight(.semibold))
                .foregroundStyle(isSelected ? RSR.labelPrimary : RSR.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? RSR.surfaceGlassStrong : RSR.accentTint)
                .clipShape(RoundedRectangle(cornerRadius: RSRRadius.chip, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
