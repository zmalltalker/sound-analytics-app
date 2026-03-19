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
    @State private var settings       = AudioSettings()
    @State private var showAdvanced   = false
    @State private var recordingStartedAt: Date?
    @Environment(\.dismiss) private var dismiss

    let onComplete: (CompletedRecording) -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    micModeSection
                    spectrumSection
                    levelMeterSection
                    if showAdvanced {
                        advancedSection
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    recordButton
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Sound Format")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    if recorder.isRecording {
                        recorder.stop()
                    }
                    dismiss()
                }
                .foregroundStyle(.cyan)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(showAdvanced ? "Simple" : "Advanced") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showAdvanced.toggle()
                    }
                }
                .foregroundStyle(.cyan)
            }
        }
        .preferredColorScheme(.dark)
        .task { await recorder.requestPermission() }
    }

    // MARK: - Mic Mode

    private var micModeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Microphone Mode")

            VStack(spacing: 6) {
                ForEach(MicMode.allCases) { mode in
                    MicModeRow(mode: mode, isSelected: settings.micMode == mode) {
                        guard !recorder.isRecording else { return }
                        settings.micMode = mode
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Spectrum

    private var spectrumSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionLabel("Frequency Spectrum")
                Spacer()
                Text("20 Hz – \(nyquistLabel)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            SpectrumView(bands: recorder.frequencyBands)
                .frame(height: 88)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Level Meter

    private var levelMeterSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Input Level")

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(levelGradient)
                        .frame(width: max(4, geo.size.width * CGFloat(recorder.inputLevel)))
                        .animation(.easeOut(duration: 0.06), value: recorder.inputLevel)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Advanced Settings

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Divider()
                .background(Color.white.opacity(0.12))

            sectionLabel("Advanced")

            // Sample Rate
            VStack(alignment: .leading, spacing: 6) {
                Text("Sample Rate")
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Picker("Sample Rate", selection: $settings.sampleRate) {
                    ForEach(RecordSampleRate.allCases) { rate in
                        Text("\(rate.label)  —  \(rate.detail)").tag(rate)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 110)
                .clipped()
                .disabled(recorder.isRecording)

                Text("Nyquist: \(nyquistLabel) — highest reproducible frequency at this rate")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Divider().background(Color.white.opacity(0.08))

            // Channels
            VStack(alignment: .leading, spacing: 8) {
                Text("Channels")
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Picker("Channels", selection: $settings.channels) {
                    ForEach(RecordChannels.allCases) { ch in
                        Text(ch.label).tag(ch)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(recorder.isRecording)
            }

            Divider().background(Color.white.opacity(0.08))

            // Encoding
            VStack(alignment: .leading, spacing: 8) {
                Text("Encoding")
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Picker("Encoding", selection: $settings.encoding) {
                    ForEach(RecordEncoding.allCases) { enc in
                        Text(enc.rawValue).tag(enc)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(recorder.isRecording)

                Text(settings.encoding.detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Record Button

    private var recordButton: some View {
        VStack(spacing: 14) {
            if recorder.permissionDenied {
                permissionDeniedView
            } else {
                Button {
                    if recorder.isRecording {
                        let recordingEndedAt = Date()
                        recorder.stop()
                        if let url = recorder.lastRecordingURL {
                            let startDate = recordingStartedAt ?? recordingEndedAt
                            let duration = recordingDuration(for: url, fallbackStartDate: startDate, endDate: recordingEndedAt)
                            onComplete(
                                CompletedRecording(
                                    fileURL: url,
                                    startTimestamp: Int(startDate.timeIntervalSince1970),
                                    endTimestamp: Int(recordingEndedAt.timeIntervalSince1970),
                                    audioEndTimestamp: duration
                                )
                            )
                            dismiss()
                        }
                    } else {
                        recordingStartedAt = Date()
                        recorder.start(settings: settings)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(recorder.isRecording ? Color.red : Color.cyan)
                            .frame(width: 76, height: 76)
                            .shadow(color: recorder.isRecording ? .red.opacity(0.5) : .cyan.opacity(0.4),
                                    radius: recorder.isRecording ? 16 : 8)

                        if recorder.isRecording {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.white)
                                .frame(width: 26, height: 26)
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.title2)
                                .foregroundStyle(.black)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: recorder.isRecording)
                }
                .buttonStyle(.plain)

                statusLine
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var statusLine: some View {
        if recorder.isRecording {
            VStack(spacing: 4) {
                Text("Recording  ·  \(settings.micMode.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.red)
                Text("Tap again to finish")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        } else if let url = recorder.lastRecordingURL {
            Text("Saved: \(url.lastPathComponent)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }

        if let err = recorder.errorMessage {
            Text(err)
                .font(.caption2)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "mic.slash")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Microphone access is required.")
                .font(.subheadline)

            Button("Open Settings") {
                if let url = URL(string: "app-settings:") {
                    UIApplication.shared.open(url)
                }
            }
            .foregroundStyle(.cyan)
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private var nyquistLabel: String {
        let hz = settings.sampleRate.nyquist
        return hz >= 1_000 ? "\(Int(hz / 1_000)) kHz" : "\(Int(hz)) Hz"
    }

    private var levelGradient: LinearGradient {
        LinearGradient(colors: [.green, .yellow, .orange, .red],
                       startPoint: .leading, endPoint: .trailing)
    }

    private func recordingDuration(for fileURL: URL, fallbackStartDate: Date, endDate: Date) -> Double {
        let assetDuration = AVURLAsset(url: fileURL).duration.seconds
        if assetDuration.isFinite, assetDuration > 0 {
            return assetDuration
        }
        return max(0, endDate.timeIntervalSince(fallbackStartDate))
    }
}

// MARK: - MicModeRow

struct MicModeRow: View {
    let mode:       MicMode
    let isSelected: Bool
    let action:     () -> Void

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
    let bands: [Float]

    var body: some View {
        GeometryReader { geo in
            let barWidth = (geo.size.width - CGFloat(bands.count - 1)) / CGFloat(bands.count)

            HStack(alignment: .bottom, spacing: 1) {
                ForEach(0..<bands.count, id: \.self) { i in
                    let value = CGFloat(bands[i])
                    // Hue shifts from blue (0.60) at low frequencies to green (0.35) at high.
                    let hue   = 0.60 - Double(i) / Double(bands.count) * 0.25

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hue: hue, saturation: 0.85, brightness: 0.9))
                        .frame(
                            width:  max(1, barWidth),
                            height: max(2, geo.size.height * value)
                        )
                        .animation(.easeOut(duration: 0.05), value: value)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(6)
        }
    }
}

#Preview {
    NavigationStack {
        RecordingView { recording in
            print("Recording completed: \(recording.fileURL)")
        }
    }
}
