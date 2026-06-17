import AVFoundation
import SwiftUI

struct DetectionTab: View {
    @Binding var showProfileSheet: Bool

    let detectionService: any EventDetectionServicing
    let modelProvider: any DetectionModelProviding
    private let waveformLoader = WaveformLoader()

    @StateObject private var recorder = AudioRecorder()
    @State private var settings = AudioSettings()
    @State private var models: [DetectionModelDescriptor] = []
    @State private var selectedModelID: DetectionModelDescriptor.ID?
    @State private var currentRecording: CompletedRecording?
    @State private var results: [DetectionEvent] = []
    @State private var waveformSamples: [Double] = []
    @State private var isLoadingModels = false
    @State private var modelLoadError: String?
    @State private var isRunningDetection = false
    @State private var isLoadingWaveform = false
    @State private var detectionError: String?
    @State private var waveformError: String?
    @State private var showAdvancedSettings = false
    @State private var recordingStartedAt: Date?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let currentRecording, !recorder.isRecording {
                        DetectionResultsSection(
                            recording: currentRecording,
                            samples: waveformSamples,
                            events: results,
                            isLoadingWaveform: isLoadingWaveform,
                            isRunningDetection: isRunningDetection,
                            detectionError: detectionError,
                            waveformError: waveformError,
                            onRecordAgain: startRecording
                        )
                    }

                    controlPanel

                    if recorder.isRecording {
                        recordingPanel
                    } else if currentRecording == nil {
                        idlePanel
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Detection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAdvancedSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundStyle(.cyan)
                    }
                }
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
            .sheet(isPresented: $showAdvancedSettings) {
                NavigationStack {
                    AdvancedSettingsView(settings: $settings, isRecording: recorder.isRecording)
                }
                .preferredColorScheme(.dark)
            }
            .task {
                await recorder.requestPermission()
                loadModels()
            }
        }
    }

    private var selectedModel: DetectionModelDescriptor? {
        models.first(where: { $0.id == selectedModelID })
    }

    private var hasResults: Bool {
        currentRecording != nil
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            modelRow

            if recorder.permissionDenied {
                permissionDeniedCard
            } else if !hasResults {
                primaryRecordButton
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var modelRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Model")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isLoadingModels {
                    Text("Loading models...")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                } else if let modelLoadError {
                    Text(modelLoadError)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                } else {
                    Text(selectedModel?.displayName ?? "No model selected")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if modelLoadError != nil {
                Button("Retry", action: loadModels)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.cyan)
            } else {
                Menu {
                    ForEach(models) { model in
                        Button(model.displayName) {
                            selectedModelID = model.id
                        }
                    }
                } label: {
                    Text("Change")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.06))
                        )
                }
                .disabled(isLoadingModels || models.isEmpty)
            }
        }
    }

    private var primaryRecordButton: some View {
        Button(action: startRecording) {
            HStack(spacing: 12) {
                Image(systemName: "mic.circle.fill")
                    .font(.title3)
                Text("Start Recording")
                    .font(.headline)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(selectedModel == nil ? Color.gray : Color.cyan)
            )
        }
        .buttonStyle(.plain)
        .disabled(selectedModel == nil || isLoadingModels)
    }

    private var recordingPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Recording - \(settings.micMode.rawValue)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)

                Spacer()

                Text("Detection will start when you stop.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Frequency Spectrum")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("20 Hz - \(nyquistLabel)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                SpectrumView(bands: recorder.frequencyBands)
                    .frame(height: 110)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Input Level")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.white.opacity(0.08))
                        RoundedRectangle(cornerRadius: 5)
                            .fill(levelGradient)
                            .frame(width: max(6, geo.size.width * CGFloat(recorder.inputLevel)))
                            .animation(.easeOut(duration: 0.06), value: recorder.inputLevel)
                    }
                }
                .frame(height: 10)
            }

            Button(action: finishRecordingAndRunDetection) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 88, height: 88)
                        .shadow(color: .red.opacity(0.45), radius: 18)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white)
                        .frame(width: 28, height: 28)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.cyan.opacity(0.14), lineWidth: 1)
        )
    }

    private var idlePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Capture a clip to analyze it with the selected model.")
                .font(.subheadline)
                .foregroundStyle(.primary)

            Text("The spectrum and input meter will expand here as soon as recording starts.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private var permissionDeniedCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "mic.slash.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            Text("Microphone access is required to run detection.")
                .font(.subheadline)
                .multilineTextAlignment(.center)

            Button("Open Settings") {
                if let url = URL(string: "app-settings:") {
                    UIApplication.shared.open(url)
                }
            }
            .foregroundStyle(.cyan)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.orange.opacity(0.12))
        )
    }

    private func loadModels() {
        isLoadingModels = true
        modelLoadError = nil

        Task {
            do {
                let loadedModels = try await modelProvider.availableModels()
                models = loadedModels
                if selectedModelID == nil {
                    selectedModelID = loadedModels.first?.id
                }
            } catch {
                modelLoadError = error.localizedDescription
            }
            isLoadingModels = false
        }
    }

    private func startRecording() {
        guard selectedModel != nil else { return }
        guard !recorder.isRecording else { return }

        recorder.refreshPermission()
        guard !recorder.permissionDenied else { return }

        detectionError = nil
        waveformError = nil
        recordingStartedAt = Date()
        recorder.start(settings: settings)
    }

    private func finishRecordingAndRunDetection() {
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

        runDetection(for: recording)
    }

    private func runDetection(for recording: CompletedRecording) {
        guard let selectedModel else { return }

        currentRecording = recording
        detectionError = nil
        waveformError = nil
        results = []
        waveformSamples = []
        isRunningDetection = true
        isLoadingWaveform = true

        Task {
            do {
                waveformSamples = try waveformLoader.loadSamples(from: recording.fileURL)
            } catch {
                waveformError = error.localizedDescription
            }
            isLoadingWaveform = false
        }

        Task {
            do {
                results = try await detectionService.recognizeEvents(in: recording, model: selectedModel)
            } catch {
                detectionError = error.localizedDescription
            }
            isRunningDetection = false
        }
    }

    private var nyquistLabel: String {
        let hz = settings.sampleRate.nyquist
        return hz >= 1_000 ? "\(Int(hz / 1_000)) kHz" : "\(Int(hz)) Hz"
    }

    private var levelGradient: LinearGradient {
        LinearGradient(colors: [.yellow, .orange, .red], startPoint: .leading, endPoint: .trailing)
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

private enum DetectionFormatters {
    static let clipDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

struct DetectionResultsSection: View {
    let recording: CompletedRecording
    let samples: [Double]
    let events: [DetectionEvent]
    let isLoadingWaveform: Bool
    let isRunningDetection: Bool
    let detectionError: String?
    let waveformError: String?
    let onRecordAgain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Latest Detection")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Recorded \(clipTimestamp)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Record Again", action: onRecordAgain)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                    )
            }

            if isLoadingWaveform {
                loadingCard("Building waveform...")
            } else if let waveformError {
                errorCard(waveformError)
            } else {
                DetectionTimelineCard(
                    samples: samples,
                    duration: recording.audioEndTimestamp,
                    events: events
                )
            }

            if isRunningDetection {
                loadingCard("Running recognition...")
            } else if let detectionError {
                errorCard(detectionError)
            }
        }
    }

    private var clipTimestamp: String {
        let date = Date(timeIntervalSince1970: TimeInterval(recording.startTimestamp))
        return DetectionFormatters.clipDate.string(from: date)
    }

    private func loadingCard(_ title: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.cyan)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func errorCard(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.red.opacity(0.12))
            )
    }
}

struct DetectionTimelineCard: View {
    let samples: [Double]
    let duration: Double
    let events: [DetectionEvent]

    private let analysisColor = Color(red: 0.41, green: 0.80, blue: 1.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !events.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Markers")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                                HStack(spacing: 6) {
                                    markerBadge(index)

                                    Text(event.title)
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.05))
                                )
                            }
                        }
                    }
                }
            }

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.05))

                GeometryReader { geometry in
                    ZStack(alignment: .bottomLeading) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            let xStart = xPosition(for: event.startTime, width: geometry.size.width)
                            let xEnd = xPosition(for: event.endTime, width: geometry.size.width)

                            RoundedRectangle(cornerRadius: 8)
                                .fill(analysisColor.opacity(0.18))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(analysisColor.opacity(0.55), lineWidth: 1)
                                )
                                .frame(width: max(8, xEnd - xStart), height: geometry.size.height - 18)
                                .offset(x: xStart, y: 0)
                        }

                        HStack(alignment: .bottom, spacing: 2) {
                            ForEach(Array(displaySamples.enumerated()), id: \.offset) { index, sample in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(barColor(for: sampleTime(for: index)))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: max(10, (geometry.size.height - 26) * sample))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                    }
                }
                .frame(height: 140)
            }
            .frame(height: 140)

            HStack {
                Text("00:00")
                Spacer()
                Text(formattedTime(duration))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if !events.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        HStack(spacing: 10) {
                            markerBadge(index)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.primary)

                                Text(event.timeRange)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(confidenceText(for: event))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.08))
                                )
                        }
                    }
                }
            } else {
                Text("No labeled events found.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var displaySamples: [Double] {
        samples.isEmpty ? Array(repeating: 0.08, count: 80) : samples
    }

    private func barColor(for time: Double) -> Color {
        if events.contains(where: { time >= $0.startTime && time <= $0.endTime }) {
            return analysisColor
        }

        return .white.opacity(0.75)
    }

    private func sampleTime(for index: Int) -> Double {
        guard !displaySamples.isEmpty else { return 0 }
        return duration * (Double(index) / Double(max(displaySamples.count - 1, 1)))
    }

    private func xPosition(for time: Double, width: Double) -> Double {
        guard duration > 0 else { return 0 }
        let progress = min(max(time / duration, 0), 1)
        return progress * width
    }

    private func formattedTime(_ value: Double) -> String {
        let totalSeconds = max(0, Int(value.rounded(.down)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func markerBadge(_ index: Int) -> some View {
        return ZStack {
            Circle()
                .fill(analysisColor)
                .frame(width: 22, height: 22)

            Text("\(index + 1)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.black)
        }
    }

    private func confidenceText(for event: DetectionEvent) -> String {
        "\(Int((event.confidence * 100).rounded()))%"
    }
}
