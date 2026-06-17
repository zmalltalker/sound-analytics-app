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
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("These settings are used for all new recordings in training and detection.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(settingsStore.settings.summaryText)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.white.opacity(0.06))

            Section("Microphone Mode") {
                ForEach(MicMode.allCases) { mode in
                    MicModeRow(mode: mode, isSelected: settingsStore.settings.micMode == mode) {
                        settingsStore.settings.micMode = mode
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                }
            }
            .listRowBackground(Color.white.opacity(0.06))

            Section("Sample Rate") {
                Picker("Sample Rate", selection: $settingsStore.settings.sampleRate) {
                    ForEach(RecordSampleRate.allCases) { rate in
                        Text("\(rate.label) - \(rate.detail)").tag(rate)
                    }
                }
                .pickerStyle(.navigationLink)

                Text("Nyquist: \(nyquistLabel) - highest reproducible frequency at this rate")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.white.opacity(0.06))

            Section("Channels") {
                Picker("Channels", selection: $settingsStore.settings.channels) {
                    ForEach(RecordChannels.allCases) { channel in
                        Text(channel.label).tag(channel)
                    }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.white.opacity(0.06))

            Section("Encoding") {
                Picker("Encoding", selection: $settingsStore.settings.encoding) {
                    ForEach(RecordEncoding.allCases) { encoding in
                        Text(encoding.rawValue).tag(encoding)
                    }
                }
                .pickerStyle(.segmented)

                Text(settingsStore.settings.encoding.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.white.opacity(0.06))
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Recording Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var nyquistLabel: String {
        let hz = settingsStore.settings.sampleRate.nyquist
        return hz >= 1_000 ? "\(Int(hz / 1_000)) kHz" : "\(Int(hz)) Hz"
    }
}
