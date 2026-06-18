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

    private let waveformLoader = WaveformLoader()
    private let accentBlue = Color(red: 0.11, green: 0.53, blue: 0.98)

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
                selectedVersion = appContext.defaultInstalledModel(for: activeProjectUID)?.version
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
    }

    private var immersiveBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.05, blue: 0.09),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color(red: 0.05, green: 0.14, blue: 0.27).opacity(0.9),
                    Color(red: 0.03, green: 0.07, blue: 0.12).opacity(0.5),
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
            VStack(alignment: .leading, spacing: 18) {
                header(for: activeProject)
                modelSelector(for: activeProject.uid)

                VStack(spacing: 10) {
                    statusBadge
                    timerLabel
                    waveformSection
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

                Spacer(minLength: 0)

                primaryActionButton(for: activeProject.uid)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, max(110, geo.safeAreaInsets.bottom + 84))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func header(for activeProject: Project) -> some View {
        HStack(alignment: .center) {
            Text("Detect")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer(minLength: 16)

            Button {} label: {
                HStack(spacing: 10) {
                    Text(activeProject.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func modelSelector(for projectUID: String) -> some View {
        let currentModel = selectedModelForDisplay(projectUID: projectUID)

        return Button {} label: {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(accentBlue, lineWidth: 2)
                    .frame(width: 24, height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(accentBlue, lineWidth: 2)
                            .frame(width: 24, height: 9)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedModelTitle(for: projectUID, model: currentModel))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(modelSubtitle(for: projectUID, model: currentModel))
                        .font(.subheadline.weight(.regular))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var statusBadge: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentBlue.opacity(0.18))
                    .frame(width: 28, height: 28)
                    .scaleEffect(recorder.isRecording && shouldPulseListeningIndicator ? 1.2 : 0.95)
                    .opacity(recorder.isRecording && shouldPulseListeningIndicator ? 0.95 : 0.45)

                Circle()
                    .fill(phase == .listening ? accentBlue : Color.white.opacity(0.38))
                    .frame(width: 16, height: 16)
            }

            Text(phase == .listening ? "LISTENING" : "READY")
                .font(.headline.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(phase == .listening ? accentBlue : Color.white.opacity(0.45))
        }
    }

    private var timerLabel: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(formattedElapsedTime(referenceDate: context.date))
                .font(.system(size: 72, weight: .ultraLight, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
    }

    private var waveformSection: some View {
        SpectrumView(
            bands: recorder.frequencyBands,
            style: .mirroredBars,
            tint: accentBlue
        )
        .frame(height: 220)
        .padding(.horizontal, 14)
        .opacity(recorder.permissionDenied ? 0.25 : 1)
        .overlay {
            if recorder.permissionDenied {
                VStack(spacing: 12) {
                    Image(systemName: "mic.slash.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.orange)

                    Text("Microphone access is required.")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func primaryActionButton(for projectUID: String) -> some View {
        Button {
            if recorder.isRecording {
                stopListening()
            } else {
                startListening(projectUID: projectUID)
            }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    if recorder.isRecording {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 1.0, green: 0.32, blue: 0.26))
                            .frame(width: 34, height: 34)
                            .shadow(color: Color.red.opacity(0.45), radius: 16)
                    } else {
                        Circle()
                            .fill(accentBlue)
                            .frame(width: 14, height: 14)
                    }
                }
                .frame(width: 40, height: 40)

                Text(recorder.isRecording ? "Stop & analyze" : "Start detection")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canStartDetection(projectUID: projectUID) && !recorder.isRecording)
    }

    private var resultsContainer: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let activeProject = appContext.activeProject {
                    header(for: activeProject)
                }

                resultsView
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 110)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Detect")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            InstrumentCard {
                Text("Create a project in Settings to start detection.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                    phase = .ready
                    startMonitoringIfNeeded()
                } label: {
                    Text("Back to detect")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
                .buttonStyle(TintedActionButtonStyle(tint: accentBlue))
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

            if isRunningDetection {
                ProgressView("Analyzing recording...")
                    .tint(accentBlue)
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
        if recorder.isRecording {
            AppHaptics.stepTick()
        }
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
