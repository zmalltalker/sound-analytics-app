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
    @State private var phase: DetectPhase = .ready
    @State private var selectedVersion: String?
    @State private var selectedRecording: CompletedRecording?
    @State private var selectedModel: InstalledProjectModel?
    @State private var results: [DetectionEvent] = []
    @State private var waveformSamples: [Double] = []
    @State private var waveformError: String?
    @State private var detectionError: String?
    @State private var isRunningDetection = false
    @State private var recordingStartedAt: Date?
    @State private var shouldPulseListeningIndicator = false
    @State private var showModelSelectorSheet = false

    private let waveformLoader = WaveformLoader()

    var body: some View {
        ZStack {
            immersiveBackground

            if let activeProject = appContext.activeProject {
                if phase == .results {
                    resultsContainer
                } else {
                    detectorSurface(for: activeProject)
                }
            } else {
                emptyState
            }
        }
        .task {
            await recorder.requestPermission()
            startMonitoringIfNeeded()
        }
        .task(id: appContext.activeProjectUID) {
            if let activeProjectUID = appContext.activeProjectUID {
                await appContext.refreshAvailableModelVersions(for: activeProjectUID, force: false)
                let currentModel = appContext.selectedOrOnlyInstalledModel(
                    for: activeProjectUID,
                    selectedVersion: selectedVersion
                ) ?? appContext.activeProjectInstalledModels.first
                selectedVersion = currentModel?.version
                selectedModel = currentModel
            }
            phase = .ready
            selectedRecording = nil
            results = []
            detectionError = nil
            waveformError = nil
            startMonitoringIfNeeded()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                shouldPulseListeningIndicator = true
            }
        }
        .onDisappear {
            if recorder.isRecording {
                recorder.stop()
            } else {
                recorder.stopMonitoring()
            }
        }
        .sheet(isPresented: $showModelSelectorSheet) {
            DetectModelSelectorSheet(
                models: appContext.activeProjectInstalledModels,
                selectedVersion: selectedVersion
            ) { model in
                selectedVersion = model.version
                selectedModel = model
                appContext.setDefaultModelVersion(model.version, for: model.projectUID)
                AppHaptics.success()
            }
        }
    }

    private var immersiveBackground: some View {
        ZStack {
            RSR.canvas

            RadialGradient(
                colors: [
                    RSR.accent.opacity(0.18),
                    RSR.accent.opacity(0.08),
                    .clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 360
            )
            .blur(radius: 8)
        }
        .ignoresSafeArea()
    }

    private func detectorSurface(for activeProject: Project) -> some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: RSRSpace.md) {
                header(for: activeProject)
                modelSelector(for: activeProject.uid)

                VStack(spacing: RSRSpace.sm) {
                    statusBadge
                    timerLabel
                    waveformSection
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

                Spacer(minLength: 0)

                primaryActionButton(for: activeProject.uid)
            }
            .padding(.horizontal, RSRSpace.screen)
            .padding(.top, RSRSpace.sm)
            .padding(.bottom, max(110, geo.safeAreaInsets.bottom + 84))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func header(for activeProject: Project) -> some View {
        HStack(alignment: .center) {
            Text("Detect")
                .font(.rsrLargeTitle)
                .tracking(RSRTracking.largeTitle)
                .foregroundStyle(RSR.labelPrimary)

            Spacer(minLength: 16)

            RSRProjectChip(name: activeProject.name) {
                showProjectSwitcher = true
            }
        }
    }

    private func modelSelector(for projectUID: String) -> some View {
        let currentModel = selectedModelForDisplay(projectUID: projectUID)

        return Button {
            showModelSelectorSheet = true
        } label: {
            RSRListRow(
                title: selectedModelTitle(for: projectUID, model: currentModel),
                subtitle: modelSubtitle(for: projectUID, model: currentModel),
                systemImage: "square.stack.3d.up"
            )
        }
        .buttonStyle(.plain)
    }

    private var statusBadge: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(RSR.accent.opacity(0.18))
                    .frame(width: 28, height: 28)
                    .scaleEffect(recorder.isRecording && shouldPulseListeningIndicator ? 1.2 : 0.95)
                    .opacity(recorder.isRecording && shouldPulseListeningIndicator ? 0.95 : 0.45)

                Circle()
                    .fill(phase == .listening ? RSR.accent : RSR.labelTertiary)
                    .frame(width: 16, height: 16)
            }

            Text(phase == .listening ? "LISTENING" : "READY")
                .font(.rsrCaption)
                .tracking(RSRTracking.eyebrow)
                .foregroundStyle(phase == .listening ? RSR.accent : RSR.labelSecondary)
        }
    }

    private var timerLabel: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(formattedElapsedTime(referenceDate: context.date))
                .font(.rsrDisplay)
                .tracking(RSRTracking.display)
                .monospacedDigit()
                .foregroundStyle(RSR.labelPrimary)
                .contentTransition(.numericText())
        }
    }

    private var waveformSection: some View {
        SpectrumView(
            bands: recorder.frequencyBands,
            style: .mirroredBars,
            tint: RSR.accent,
            mirroredHorizontalPadding: 10
        )
        .frame(height: 220)
        .padding(.horizontal, 14)
        .opacity(recorder.permissionDenied ? 0.25 : 1)
        .overlay {
            if recorder.permissionDenied {
                VStack(spacing: 12) {
                    Image(systemName: "mic.slash.fill")
                        .font(.rsrLargeTitle)
                        .foregroundStyle(RSR.warning)

                    Text("Microphone access is required.")
                        .font(.rsrHeadline)
                        .foregroundStyle(RSR.labelPrimary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .rsrGlass(.regular, radius: RSRRadius.card, fill: RSR.surfaceGlassStrong, elevation: .card)
            }
        }
    }

    private func primaryActionButton(for projectUID: String) -> some View {
        Button {
            if recorder.isRecording {
                AppHaptics.success()
                stopListening()
            } else {
                AppHaptics.stepTick()
                startListening(projectUID: projectUID)
            }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    if recorder.isRecording {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(RSR.danger)
                            .frame(width: 34, height: 34)
                            .shadow(color: RSR.danger.opacity(0.45), radius: 16)
                    } else {
                        Circle()
                            .fill(RSR.accent)
                            .frame(width: 14, height: 14)
                    }
                }
                .frame(width: 40, height: 40)

                Text(recorder.isRecording ? "Stop & analyze" : "Start detection")
                    .font(.rsrHeadline)
                    .foregroundStyle(RSR.labelPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .rsrGlass(.regular, radius: RSRRadius.card, fill: RSR.surfaceGlassStrong, elevation: .card)
        }
        .buttonStyle(.plain)
        .opacity(!canStartDetection(projectUID: projectUID) && !recorder.isRecording ? 0.45 : 1)
        .disabled(!canStartDetection(projectUID: projectUID) && !recorder.isRecording)
    }

    private var resultsContainer: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RSRSpace.md) {
                if let activeProject = appContext.activeProject {
                    header(for: activeProject)
                }

                resultsView
            }
            .padding(.horizontal, RSRSpace.screen)
            .padding(.top, RSRSpace.sm)
            .padding(.bottom, 110)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: RSRSpace.md) {
            Text("Detect")
                .font(.rsrLargeTitle)
                .tracking(RSRTracking.largeTitle)
                .foregroundStyle(RSR.labelPrimary)

            RSRCard {
                Text("Create a project in Settings to start detection.")
                    .font(.rsrSubhead)
                    .foregroundStyle(RSR.labelSecondary)
            }
        }
        .padding(RSRSpace.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var resultsView: some View {
        VStack(alignment: .leading, spacing: RSRSpace.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Latest detection")
                        .font(.rsrHeadline)
                        .foregroundStyle(RSR.labelPrimary)
                    if let selectedRecording {
                        Text(Date(timeIntervalSince1970: selectedRecording.startTimestamp).formatted(date: .abbreviated, time: .shortened))
                            .font(.rsrMeta)
                            .foregroundStyle(RSR.labelSecondary)
                    }
                }

                Spacer()

                RSRTonalButton(title: "Back to detect") {
                    phase = .ready
                    startMonitoringIfNeeded()
                }
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
                    .font(.rsrSubhead)
                    .foregroundStyle(RSR.danger)
            }

            if let detectionError {
                Text(detectionError)
                    .font(.rsrSubhead)
                    .foregroundStyle(RSR.danger)
            }

            if isRunningDetection {
                ProgressView("Analyzing recording...")
                    .tint(RSR.accent)
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

    private func startMonitoringIfNeeded() {
        guard phase != .results else { return }
        guard !recorder.isRecording else { return }
        recorder.refreshPermission()
        guard !recorder.permissionDenied else { return }
        recorder.startMonitoring(settings: recordingSettingsStore.settings)
    }

    private func selectedModelForDisplay(projectUID: String) -> InstalledProjectModel? {
        if let selectedVersion,
           let match = appContext.installedModels.first(where: { $0.projectUID == projectUID && $0.version == selectedVersion }) {
            return match
        }

        return appContext.defaultInstalledModel(for: projectUID)
            ?? appContext.activeProjectInstalledModels.first
    }

    private func selectedModelTitle(for projectUID: String, model: InstalledProjectModel?) -> String {
        if let model {
            return "Model v\(model.version)"
        }
        if let version = selectedVersion {
            return "Model v\(version)"
        }
        if let defaultModel = appContext.defaultInstalledModel(for: projectUID) {
            return "Model v\(defaultModel.version)"
        }
        return "Choose model"
    }

    private func modelSubtitle(for projectUID: String, model: InstalledProjectModel?) -> String {
        guard let model else {
            return "No model installed"
        }

        let isDefault = appContext.defaultModelVersionsByProject[projectUID] == model.version
        let defaultText = isDefault ? "Default" : "Installed"
        return "\(defaultText) · \(model.labelCount) labels · on device"
    }

    private func canStartDetection(projectUID: String) -> Bool {
        appContext.selectedOrOnlyInstalledModel(for: projectUID, selectedVersion: selectedVersion) != nil
    }

    private func formattedElapsedTime(referenceDate: Date) -> String {
        guard phase == .listening, let recordingStartedAt else {
            return "0:00"
        }

        let elapsed = max(0, Int(referenceDate.timeIntervalSince(recordingStartedAt)))
        return "\(elapsed / 60):" + String(format: "%02d", elapsed % 60)
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
    case ready
    case listening
    case results
}
