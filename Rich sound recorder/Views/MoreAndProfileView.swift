import AVFoundation
import SwiftUI

struct MoreTab: View {
    let loginService: AuthenticationService
    @Binding var showProfileSheet: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                List {
                    Section("Browse") {
                        NavigationLink {
                            ProjectsTab(
                                loginService: loginService,
                                showProfileSheet: $showProfileSheet,
                                wrapInNavigation: false
                            )
                        } label: {
                            moreRow(
                                title: "Projects",
                                subtitle: "Manage project groups and assigned labels",
                                systemImage: "folder.fill"
                            )
                        }

                        NavigationLink {
                            LabelsTab(
                                loginService: loginService,
                                showProfileSheet: $showProfileSheet,
                                wrapInNavigation: false
                            )
                        } label: {
                            moreRow(
                                title: "Labels",
                                subtitle: "Create and review training labels",
                                systemImage: "tag.fill"
                            )
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showProfileSheet = true
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.cyan)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func moreRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.cyan)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

struct UploadLabelSheet: View {
    let fileURL: URL?
    let labels: [RecorderLabel]
    let isLoadingLabels: Bool
    let labelLoadingError: String?
    @Binding var selectedLabelUID: String?
    let isUploading: Bool
    let onCancel: () -> Void
    let onRetry: () -> Void
    let onUpload: () -> Void
    @StateObject private var settingsStore = RecordingSettingsStore.shared
    @State private var waveformSamples: [Double] = []
    @State private var displayedDuration: String = "0:00"

    private let waveformLoader = WaveformLoader()
    private let waveformBlue = Color(red: 0.11, green: 0.53, blue: 0.98)
    private let sheetFill = Color.white.opacity(0.11)
    private let sheetStroke = Color.white.opacity(0.07)
    private let chipColumns = [
        GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 12, alignment: .leading)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    VStack(alignment: .leading, spacing: 24) {
                        Capsule()
                            .fill(Color.white.opacity(0.22))
                            .frame(width: 76, height: 8)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 6)

                        HStack(alignment: .bottom, spacing: 12) {
                            Text("New recording")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Spacer()

                            Text(displayedDuration)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.08))
                                )
                        }

                        waveformCard

                        VStack(alignment: .leading, spacing: 14) {
                            Text("CHOOSE A LABEL")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .tracking(1.6)
                                .foregroundStyle(Color.white.opacity(0.45))

                            labelSection
                        }

                        NavigationLink {
                            RecordingSettingsScreen()
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Recording quality")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)

                                    Text(recordingQualitySummary)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(Color.white.opacity(0.32))
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(sheetStroke, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        VStack(spacing: 14) {
                            Button(action: onUpload) {
                                if isUploading {
                                    ProgressView()
                                        .tint(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 18)
                                } else {
                                    Text("Upload to dataset")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 18)
                                }
                            }
                            .buttonStyle(.plain)
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.29, green: 0.64, blue: 1.0),
                                                Color(red: 0.09, green: 0.51, blue: 0.98)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                            .shadow(color: waveformBlue.opacity(0.33), radius: 18, y: 10)
                            .opacity(uploadEnabled ? 1 : 0.45)
                            .disabled(!uploadEnabled || isUploading)

                            Button("Discard", action: onCancel)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(red: 1.0, green: 0.32, blue: 0.26))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 18)
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 34,
                            bottomLeadingRadius: 28,
                            bottomTrailingRadius: 28,
                            topTrailingRadius: 34
                        )
                        .fill(Color(red: 0.11, green: 0.11, blue: 0.12))
                    )
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 34,
                            bottomLeadingRadius: 28,
                            bottomTrailingRadius: 28,
                            topTrailingRadius: 34
                        )
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                }
            }
            .task(id: fileURL) {
                loadRecordingPreview()
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.height(620)])
        .presentationDragIndicator(.hidden)
    }

    private var uploadEnabled: Bool {
        !isLoadingLabels && !labels.isEmpty && selectedLabelUID != nil && labelLoadingError == nil
    }

    @ViewBuilder
    private var labelSection: some View {
        if isLoadingLabels {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(.white)
                Text("Loading labels...")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .padding(.vertical, 8)
        } else if let labelLoadingError {
            VStack(alignment: .leading, spacing: 10) {
                Text(labelLoadingError)
                    .font(.caption)
                    .foregroundStyle(.red)

                Button("Retry", action: onRetry)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(waveformBlue)
            }
        } else if labels.isEmpty {
            Text("No labels available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            LazyVGrid(columns: chipColumns, alignment: .leading, spacing: 12) {
                ForEach(labels) { label in
                    labelChip(for: label)
                }
            }
        }
    }

    private var waveformCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(red: 0.10, green: 0.16, blue: 0.24))
            RoundedRectangle(cornerRadius: 28)
                .stroke(waveformBlue.opacity(0.28), lineWidth: 1)

            if waveformSamples.isEmpty {
                ProgressView()
                    .tint(.white.opacity(0.8))
            } else {
                trainingWaveform(samples: waveformSamples)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 22)
            }
        }
        .frame(height: 148)
    }

    private func labelChip(for label: RecorderLabel) -> some View {
        let isSelected = selectedLabelUID == label.uid

        return Button {
            selectedLabelUID = label.uid
            AppHaptics.stepTick()
        } label: {
            Text(label.name)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? .white : Color.white.opacity(0.78))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(
                            isSelected
                            ? LinearGradient(
                                colors: [
                                    Color(red: 0.29, green: 0.64, blue: 1.0),
                                    Color(red: 0.09, green: 0.51, blue: 0.98)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            : LinearGradient(
                                colors: [sheetFill, sheetFill],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? waveformBlue.opacity(0.28) : Color.clear, lineWidth: 1)
                )
                .shadow(color: isSelected ? waveformBlue.opacity(0.28) : .clear, radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func trainingWaveform(samples: [Double]) -> some View {
        GeometryReader { geo in
            let barWidth = max(4, geo.size.width / CGFloat(max(samples.count, 1)) * 0.38)
            let spacing = max(3, geo.size.width / CGFloat(max(samples.count, 1)) * 0.18)

            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(waveformBlue)
                        .frame(
                            width: barWidth,
                            height: max(10, geo.size.height * CGFloat(sample))
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func loadRecordingPreview() {
        guard let fileURL else {
            waveformSamples = []
            displayedDuration = "0:00"
            return
        }

        Task {
            let samples = (try? waveformLoader.loadSamples(from: fileURL, sampleCount: 40)) ?? []
            let duration = formattedDuration(for: fileURL)

            await MainActor.run {
                waveformSamples = samples
                displayedDuration = duration
            }
        }
    }

    private func formattedDuration(for fileURL: URL) -> String {
        guard let audioFile = try? AVAudioFile(forReading: fileURL), audioFile.processingFormat.sampleRate > 0 else {
            return "0:00"
        }

        let seconds = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        let totalSeconds = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private var recordingQualitySummary: String {
        let settings = settingsStore.settings
        return "\(settings.sampleRate.label) · \(settings.channels.label) · \(settings.encoding.rawValue)"
    }
}

struct ProfileSheet: View {
    let loginService: AuthenticationService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 72))
                                .foregroundStyle(.cyan)

                            if let username = loginService.username {
                                Text(username)
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Signed in")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 20)

                        if let tokenInfo = loginService.getTokenInfo() {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Keychain Data")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(0.5)

                                VStack(spacing: 12) {
                                    InfoRow(label: "Username", value: tokenInfo.username ?? "Unknown")
                                    InfoRow(label: "Account ID", value: tokenInfo.homeAccountId)
                                    InfoRow(label: "Environment", value: tokenInfo.environment ?? "Unknown")
                                    InfoRow(label: "Keychain Group", value: "ai.resonyx.ios-recorder")
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.06))
                                )

                                Text("Access tokens, refresh tokens, and ID tokens are securely stored in iOS Keychain")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 20)
                        }

                        Button {
                            loginService.logout()
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.title3)
                                Text("Sign Out")
                                    .font(.headline)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.red.opacity(0.8))
                            )
                            .padding(.horizontal, 40)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.cyan)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.cyan)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
