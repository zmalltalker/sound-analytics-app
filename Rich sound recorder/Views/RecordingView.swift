//
//  RecordingView.swift
//  Rich sound recorder
//
//  Created by Marius Mathiesen on 17/03/2026.
//

import SwiftUI
import AVFoundation

struct RecordingView: View {
    @StateObject private var recorder = AudioRecorder()
    @StateObject private var settingsStore = RecordingSettingsStore.shared
    @State private var recordingStartedAt: Date?
    @State private var hasCompletedRecording = false
    @State private var shouldPulseIndicator = false
    @Namespace private var recordingIndicatorNamespace
    @Environment(\.dismiss) private var dismiss

    let projectName: String?
    let onComplete: (CompletedRecording) -> Void

    init(
        projectName: String? = nil,
        onComplete: @escaping (CompletedRecording) -> Void
    ) {
        self.projectName = projectName
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            immersiveBackground

            VStack(spacing: 0) {
                header

                Spacer(minLength: 10)

                VStack(spacing: 14) {
                    recordingBadge
                    timerText
                    waveformSection
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 18)

                VStack(spacing: 16) {
                    primaryActionArea
                    bottomInstruction
                }
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(false)
        .task {
            await recorder.requestPermission()
            startMonitoringIfNeeded()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                shouldPulseIndicator = true
            }
        }
        .onDisappear {
            guard !hasCompletedRecording else { return }
            discardRecordingIfNeeded()
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
                endRadius: 340
            )
            .blur(radius: 8)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .center) {
            Button("Cancel") {
                cancelAndDismiss()
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color(red: 0.15, green: 0.52, blue: 0.98))

            Spacer()

            Text(projectName ?? "Training")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.55))
                .lineLimit(1)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
    }

    private var recordingBadge: some View {
        HStack(spacing: 12) {
            ZStack {
                if recorder.isRecording {
                    Circle()
                        .fill(Color.red.opacity(0.18))
                        .frame(width: 34, height: 34)
                        .scaleEffect(shouldPulseIndicator ? 1.2 : 0.9)
                        .opacity(shouldPulseIndicator ? 0.95 : 0.45)

                    Circle()
                        .fill(Color(red: 1.0, green: 0.32, blue: 0.26))
                        .frame(width: 18, height: 18)
                        .shadow(color: Color.red.opacity(0.55), radius: 10)
                        .matchedGeometryEffect(id: "recording-indicator", in: recordingIndicatorNamespace)
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 16, height: 16)
                }
            }

            Text(recorder.isRecording ? "RECORDING" : "READY")
                .font(.headline.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(Color.white.opacity(0.55))
        }
    }

    private var timerText: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(formattedElapsedTime(referenceDate: context.date))
                .font(.system(size: 90, weight: .ultraLight, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
    }

    private var waveformSection: some View {
        SpectrumView(
            bands: recorder.frequencyBands,
            style: .mirroredBars,
            tint: Color(red: 0.11, green: 0.53, blue: 0.98)
        )
        .frame(height: 290)
        .padding(.horizontal, 22)
        .opacity(recorder.permissionDenied ? 0.25 : 1)
        .overlay {
            if recorder.permissionDenied {
                permissionDeniedView
                    .padding(.horizontal, 30)
            } else if let errorMessage = recorder.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                    )
            }
        }
    }

    @ViewBuilder
    private var primaryActionArea: some View {
        if recorder.isRecording {
            Button {
                finishRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 74, height: 74)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 2)
                        )

                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(red: 1.0, green: 0.32, blue: 0.26))
                        .frame(width: 31, height: 31)
                        .shadow(color: Color.red.opacity(0.35), radius: 18)
                }
            }
            .buttonStyle(.plain)
        } else {
            Button {
                startRecording()
            } label: {
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.32, blue: 0.26))
                        .frame(width: 18, height: 18)
                        .shadow(color: Color.red.opacity(0.45), radius: 10)
                        .matchedGeometryEffect(id: "recording-indicator", in: recordingIndicatorNamespace)

                    Text("Start recording")
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
            .disabled(recorder.permissionDenied)
        }
    }

    private var bottomInstruction: some View {
        VStack(spacing: 8) {
            Text(instructionText)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text(settingsStore.settings.summaryText)
                .font(.caption.monospaced())
                .foregroundStyle(Color.white.opacity(0.25))
        }
    }

    private var instructionText: String {
        if recorder.permissionDenied {
            return "Microphone access is required to record for training"
        }
        return recorder.isRecording ? "Tap to stop · choose a label next" : "Tap start to begin · choose a label next"
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.orange)

            Text("Microphone access is required.")
                .font(.headline)
                .foregroundStyle(.white)

            Button("Open Settings") {
                if let url = URL(string: "app-settings:") {
                    UIApplication.shared.open(url)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(red: 0.15, green: 0.52, blue: 0.98))
        }
    }

    private func startRecording() {
        guard !recorder.permissionDenied else { return }
        AppHaptics.stepTick()
        recordingStartedAt = Date()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.84)) {
            recorder.start(settings: settingsStore.settings)
        }
    }

    private func startMonitoringIfNeeded() {
        guard !recorder.permissionDenied else { return }
        guard !recorder.isRecording else { return }
        recorder.startMonitoring(settings: settingsStore.settings)
    }

    private func finishRecording() {
        guard recorder.isRecording else { return }

        AppHaptics.stepTick()
        let recordingEndedAt = Date()
        let startDate = recordingStartedAt ?? recordingEndedAt
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            recorder.stop()
        }

        guard let url = recorder.lastRecordingURL else { return }

        hasCompletedRecording = true
        let duration = recordingDuration(for: url, fallbackStartDate: startDate, endDate: recordingEndedAt)
        onComplete(
            CompletedRecording(
                fileURL: url,
                startTimestamp: startDate.timeIntervalSince1970,
                endTimestamp: recordingEndedAt.timeIntervalSince1970,
                audioEndTimestamp: duration
            )
        )
        dismiss()
    }

    private func cancelAndDismiss() {
        discardRecordingIfNeeded()
        dismiss()
    }

    private func discardRecordingIfNeeded() {
        let discardedURL = recorder.lastRecordingURL
        if recorder.isRecording {
            recorder.stop()
        } else {
            recorder.stopMonitoring()
        }

        if let discardedURL {
            try? FileManager.default.removeItem(at: discardedURL)
            if recorder.lastRecordingURL == discardedURL {
                recorder.lastRecordingURL = nil
            }
        }
    }

    private func formattedElapsedTime(referenceDate: Date) -> String {
        guard let recordingStartedAt, recorder.isRecording else {
            return "0:00"
        }

        let elapsedSeconds = max(0, Int(referenceDate.timeIntervalSince(recordingStartedAt)))
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return "\(minutes):" + String(format: "%02d", seconds)
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

// MARK: - MicModeRow

struct MicModeRow: View {
    let mode: MicMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: mode.iconName)
                    .frame(width: 22)
                    .foregroundStyle(isSelected ? .black : .cyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? .black : .primary)

                    Text(mode.subtitle)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .black.opacity(0.65) : .secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.cyan : Color.white.opacity(0.07))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SpectrumView

/// Displays real-time FFT magnitude as a bar chart with logarithmic frequency scaling.
struct SpectrumView: View {
    enum Style {
        case bottomBars
        case mirroredBars
    }

    let bands: [Float]
    var style: Style = .bottomBars
    var tint: Color? = nil

    var body: some View {
        GeometryReader { geo in
            let renderedBands = style == .mirroredBars ? interpolatedBands(targetCount: 44) : bands
            let spacing: CGFloat = style == .mirroredBars ? 7 : 1
            let horizontalPadding: CGFloat = style == .mirroredBars ? 0 : 6
            let barWidth = max(3, (geo.size.width - horizontalPadding * 2 - CGFloat(renderedBands.count - 1) * spacing) / CGFloat(renderedBands.count))

            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<renderedBands.count, id: \.self) { index in
                    let rawValue = CGFloat(max(renderedBands[index], 0))
                    let value = style == .mirroredBars
                        ? mirroredAmplitude(for: rawValue)
                        : rawValue
                    let fill = resolvedColor(for: index)
                    let heightMultiplier: CGFloat = style == .mirroredBars ? 0.94 : 1
                    let barHeight = max(style == .mirroredBars ? 8 : 6, geo.size.height * value * heightMultiplier)

                    RoundedRectangle(cornerRadius: style == .mirroredBars ? 3 : 2)
                        .fill(fill)
                        .frame(width: barWidth, height: barHeight)
                        .frame(maxHeight: .infinity, alignment: .center)
                        .shadow(color: style == .mirroredBars ? fill.opacity(0.22) : .clear, radius: 4)
                        .animation(.easeOut(duration: 0.08), value: value)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: style == .mirroredBars ? .center : .bottom)
            .padding(.horizontal, horizontalPadding)
        }
    }

    private func resolvedColor(for index: Int) -> Color {
        if let tint {
            return tint
        }

        let hue = 0.60 - Double(index) / Double(max(bands.count, 1)) * 0.25
        return Color(hue: hue, saturation: 0.85, brightness: 0.9)
    }

    private func mirroredAmplitude(for rawValue: CGFloat) -> CGFloat {
        let normalized = min(max(rawValue, 0), 1)
        let boosted = pow(normalized, 0.78) * 1.35
        return min(max(boosted + 0.015, 0.04), 1)
    }

    private func interpolatedBands(targetCount: Int) -> [Float] {
        guard style == .mirroredBars, !bands.isEmpty, targetCount > bands.count else {
            return bands
        }

        if bands.count == 1 {
            return Array(repeating: bands[0], count: targetCount)
        }

        return (0..<targetCount).map { index in
            let position = Float(index) / Float(max(targetCount - 1, 1)) * Float(bands.count - 1)
            let lowerIndex = Int(position.rounded(.down))
            let upperIndex = min(lowerIndex + 1, bands.count - 1)
            let fraction = position - Float(lowerIndex)
            let lower = bands[lowerIndex]
            let upper = bands[upperIndex]
            let interpolated = lower + (upper - lower) * fraction

            let leftNeighbor = bands[max(0, lowerIndex - 1)]
            let rightNeighbor = bands[min(bands.count - 1, upperIndex + 1)]
            return (leftNeighbor * 0.18) + (interpolated * 0.64) + (rightNeighbor * 0.18)
        }
    }
}

#Preview {
    RecordingView(projectName: "Compressor Line A") { recording in
        print("Recording completed: \(recording.fileURL)")
    }
}
