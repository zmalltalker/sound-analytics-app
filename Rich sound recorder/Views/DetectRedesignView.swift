import AVFoundation
import SwiftUI

struct DetectWorkspaceView: View {
    @Environment(RedesignAppContext.self) private var appContext

    let detectionService: any EventDetectionServicing
    @Binding var showProjectSwitcher: Bool
    let onOpenModels: () -> Void
    let onOpenTrain: () -> Void

    @StateObject private var recorder = AudioRecorder()
    @StateObject private var recordingSettingsStore = RecordingSettingsStore.shared
    @State private var phase: DetectPhase = .chooser
    @State private var selectedVersion: String?
    @State private var selectedRecording: CompletedRecording?
    @State private var selectedModel: InstalledProjectModel?
    @State private var results: [DetectionEvent] = []
    @State private var waveformSamples: [Double] = []
    @State private var waveformError: String?
    @State private var detectionError: String?
    @State private var isRunningDetection = false
    @State private var recordingStartedAt: Date?
    @State private var showSwitchConfirmation = false

    private let waveformLoader = WaveformLoader()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let activeProject = appContext.activeProject {
                    switch phase {
                    case .chooser:
                        chooserView(for: activeProject.uid)
                    case .listening:
                        listeningView
                    case .results:
                        resultsView
                    }
                } else {
                    InstrumentCard {
                        Text("Create a project in Settings to start detection.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
            .padding(.top, 8)
            .padding(.bottom, 80)
        }
        .background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            if let activeProject = appContext.activeProject {
                ContextHeader(
                    title: activeProject.name,
                    subtitle: detectSubtitle(for: activeProject.uid),
                    onSwitch: {
                        if recorder.isRecording {
                            showSwitchConfirmation = true
                        } else {
                            showProjectSwitcher = true
                            phase = .chooser
                        }
                    }
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .background(Color.clear)
            }
        }
        .task {
            await recorder.requestPermission()
        }
        .task(id: appContext.activeProjectUID) {
            if let activeProjectUID = appContext.activeProjectUID {
                await appContext.refreshAvailableModelVersions(for: activeProjectUID, force: false)
                selectedVersion = appContext.defaultInstalledModel(for: activeProjectUID)?.version
            }
            phase = .chooser
        }
        .alert("Stop detection and switch project?", isPresented: $showSwitchConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Stop and Switch") {
                if recorder.isRecording {
                    recorder.stop()
                }
                phase = .chooser
                showProjectSwitcher = true
            }
        } message: {
            Text("Changing project ends the current detection session before you switch models.")
        }
    }

    private func chooserView(for projectUID: String) -> some View {
        let installedModels = appContext.activeProjectInstalledModels

        return InstrumentCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("DETECT WITH")
                    .font(.caption.monospaced())
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                if installedModels.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("No models installed for this project")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Install one in Models or train a new version first.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Button("Open Models", action: onOpenModels)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .buttonStyle(TintedActionButtonStyle(tint: Color(red: 0.91, green: 0.47, blue: 0.32)))

                            Button("Open Train", action: onOpenTrain)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white.opacity(0.06))
                                )
                        }
                    }
                } else {
                    ForEach(installedModels) { model in
                        Button {
                            selectedVersion = model.version
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedVersion == model.version ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(selectedVersion == model.version ? Color(red: 0.41, green: 0.80, blue: 1.0) : .secondary)

                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Text("Version \(model.version)")
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        if appContext.defaultModelVersionsByProject[projectUID] == model.version {
                                            Text("★")
                                                .foregroundStyle(Color(red: 0.41, green: 0.80, blue: 1.0))
                                        }
                                    }
                                    Text("\(model.labelCount) labels · \(formattedStorage(model.sizeBytes))")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(selectedVersion == model.version ? Color(red: 0.41, green: 0.80, blue: 1.0).opacity(0.12) : Color.white.opacity(0.05))
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Showing versions of \(appContext.activeProject?.name ?? "this project") installed on this device. Switch project in the header to detect with another.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        startListening(projectUID: projectUID)
                    } label: {
                        Text("Start detecting")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(TintedActionButtonStyle(tint: Color(red: 0.91, green: 0.47, blue: 0.32)))
                    .disabled(selectedVersion == nil)
                }
            }
        }
    }

    private var listeningView: some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("● Listening")
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.91, green: 0.47, blue: 0.32))
                    Spacer()
                    Text(elapsedRecordingTime)
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(.primary)
                }

                SpectrumView(bands: recorder.frequencyBands)
                    .frame(height: 110)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.white.opacity(0.08))
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(red: 0.91, green: 0.47, blue: 0.32))
                            .frame(width: max(6, geo.size.width * CGFloat(recorder.inputLevel)))
                    }
                }
                .frame(height: 10)

                Text("Tap stop to see detected events")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    stopListening()
                } label: {
                    Text("Stop")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(TintedActionButtonStyle(tint: Color(red: 0.91, green: 0.47, blue: 0.32)))
            }
        }
    }

    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Latest detection")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if let selectedRecording {
                        Text(Date(timeIntervalSince1970: selectedRecording.startTimestamp).formatted(date: .abbreviated, time: .shortened))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    if let projectUID = appContext.activeProjectUID {
                        startListening(projectUID: projectUID)
                    } else {
                        phase = .chooser
                    }
                } label: {
                    Text("Record again")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
                .buttonStyle(TintedActionButtonStyle(tint: Color(red: 0.91, green: 0.47, blue: 0.32)))
            }

            if let selectedRecording {
                DetectionTimelineCard(
                    samples: waveformSamples,
                    duration: selectedRecording.audioEndTimestamp,
                    events: results
                )
            }

            if let waveformError {
                Text(waveformError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let detectionError {
                Text(detectionError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func startListening(projectUID: String) {
        guard !recorder.isRecording else { return }
        guard let model = appContext.selectedOrOnlyInstalledModel(for: projectUID, selectedVersion: selectedVersion) else {
            return
        }

        recorder.refreshPermission()
        guard !recorder.permissionDenied else { return }

        selectedVersion = model.version
        appContext.setDefaultModelVersion(model.version, for: projectUID)
        selectedModel = model
        results = []
        waveformSamples = []
        waveformError = nil
        detectionError = nil
        selectedRecording = nil
        recordingStartedAt = Date()
        recorder.start(settings: recordingSettingsStore.settings)
        phase = .listening
    }

    private func stopListening() {
        guard recorder.isRecording else { return }
        let recordingEndedAt = Date()
        recorder.stop()

        guard let url = recorder.lastRecordingURL else { return }

        let startDate = recordingStartedAt ?? recordingEndedAt
        let duration = recordingDuration(for: url, fallbackStartDate: startDate, endDate: recordingEndedAt)
        let recording = CompletedRecording(
            fileURL: url,
            startTimestamp: startDate.timeIntervalSince1970,
            endTimestamp: recordingEndedAt.timeIntervalSince1970,
            audioEndTimestamp: duration
        )

        selectedRecording = recording
        phase = .results
        runDetection(for: recording)
    }

    private func runDetection(for recording: CompletedRecording) {
        guard let selectedModel else { return }

        isRunningDetection = true
        waveformError = nil
        detectionError = nil
        results = []
        waveformSamples = []

        let descriptor = DetectionModelDescriptor(
            id: selectedModel.id,
            displayName: selectedModel.displayName,
            summary: "Downloaded project model with \(selectedModel.labelCount) labels",
            bundledModelName: nil,
            downloadedArchiveURL: selectedModel.archiveURL,
            labelNames: selectedModel.labelNames
        )

        Task {
            do {
                waveformSamples = try waveformLoader.loadSamples(from: recording.fileURL)
            } catch {
                waveformError = error.localizedDescription
            }
        }

        Task {
            do {
                results = try await detectionService.recognizeEvents(in: recording, model: descriptor)
            } catch {
                detectionError = error.localizedDescription
            }
            isRunningDetection = false
        }
    }

    private func detectSubtitle(for projectUID: String) -> String {
        if let selectedVersion {
            return "v\(selectedVersion) · on device"
        }

        if let defaultModel = appContext.defaultInstalledModel(for: projectUID) {
            return "v\(defaultModel.version) · on device"
        }

        return "Choose a version"
    }

    private var elapsedRecordingTime: String {
        guard let recordingStartedAt else { return "00:00" }
        let elapsed = max(0, Int(Date().timeIntervalSince(recordingStartedAt)))
        return String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
    }

    private func recordingDuration(for fileURL: URL, fallbackStartDate: Date, endDate: Date) -> Double {
        if let audioFile = try? AVAudioFile(forReading: fileURL) {
            let sampleRate = audioFile.processingFormat.sampleRate
            let frameCount = Double(audioFile.length)
            let fileDuration = frameCount / sampleRate

            if fileDuration.isFinite, fileDuration > 0 {
                return fileDuration
            }
        }

        return max(0, endDate.timeIntervalSince(fallbackStartDate))
    }
}

private enum DetectPhase {
    case chooser
    case listening
    case results
}
