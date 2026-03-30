import AVFoundation
import SwiftUI

struct SnippetPlayerView: View {
    let labelName: String
    let audioFile: SnippetAudioFile

    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var loadError: String?
    @State private var audioInfo: AudioNerdInfo?

    @State private var playbackTimer: Timer?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(labelName)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)

                    if let metadata = audioFile.metadata {
                        Text("Start: \(timestampText(metadata.start))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("End: \(timestampText(metadata.end))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(audioFile.fileURL.lastPathComponent)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    Slider(
                        value: Binding(
                            get: { currentTime },
                            set: { newValue in
                                currentTime = newValue
                                audioPlayer?.currentTime = newValue
                            }
                        ),
                        in: 0...max(duration, 0.1)
                    )

                    HStack {
                        Text(timeLabel(for: currentTime))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(timeLabel(for: duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button(action: togglePlayback) {
                    Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .disabled(audioPlayer == nil)

                if let loadError {
                    Text(loadError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if let info = audioInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nerd Data")
                            .font(.headline)
                        SnippetInfoRow(title: "Sample Rate", value: String(format: "%.0f Hz", info.sampleRate))
                        SnippetInfoRow(title: "Channels", value: "\(info.channelCount)")
                        SnippetInfoRow(title: "Bit Depth", value: info.bitDepth > 0 ? "\(info.bitDepth)-bit" : "Unknown")
                        SnippetInfoRow(title: "File Size", value: byteFormatter.string(fromByteCount: info.fileSize))
                        SnippetInfoRow(title: "Duration", value: timeLabel(for: duration))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Player")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear(perform: preparePlayer)
        .onDisappear {
            audioPlayer?.stop()
            isPlaying = false
            stopTimer()
        }
    }

    private func preparePlayer() {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioFile.fileURL)
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
            currentTime = 0
            audioInfo = try loadNerdInfo()
            startTimer()
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func togglePlayback() {
        guard let player = audioPlayer else { return }

        if player.isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
            startTimer()
        }
    }

    private func startTimer() {
        playbackTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            guard let player = audioPlayer else { return }
            if player.isPlaying {
                currentTime = player.currentTime
            } else if isPlaying {
                isPlaying = false
                currentTime = player.currentTime
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        playbackTimer = timer
    }

    private func stopTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func timeLabel(for seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "--:--" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: seconds) ?? "--:--"
    }

    private func timestampText(_ timestamp: TimeInterval) -> String {
        Date(timeIntervalSince1970: timestamp).formatted(date: .abbreviated, time: .shortened)
    }

    private func loadNerdInfo() throws -> AudioNerdInfo {
        let avFile = try AVAudioFile(forReading: audioFile.fileURL)
        let format = avFile.fileFormat
        let description = format.streamDescription.pointee
        let attrs = try FileManager.default.attributesOfItem(atPath: audioFile.fileURL.path)
        let fileSize = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        let info = AudioNerdInfo(
            sampleRate: format.sampleRate,
            channelCount: Int(format.channelCount),
            bitDepth: Int(description.mBitsPerChannel),
            fileSize: fileSize
        )
        return info
    }

    private var byteFormatter: ByteCountFormatter {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter
    }
}

private struct AudioNerdInfo {
    let sampleRate: Double
    let channelCount: Int
    let bitDepth: Int
    let fileSize: Int64
}

private struct SnippetInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }
}
