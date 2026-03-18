import SwiftUI
import UniformTypeIdentifiers

// MARK: - Root editor

struct BurstEditorView: View {
    @State private var analysis: BurstAnalysis
    @State private var selectedChunkID: UUID?
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var exportData: Data?
    @State private var exportError: String?
    @State private var exportedURL: URL?
    @State private var showExportSuccess = false

    init(analysis: BurstAnalysis = .sample) {
        _analysis = State(initialValue: analysis)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                Divider().background(Color.gray.opacity(0.3))
                timelineSection
                Divider().background(Color.gray.opacity(0.3))
                chunkList
            }
        }
        .navigationTitle("Burst Editor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Import") { showImporter = true }
                    .foregroundColor(.cyan)
                Button("Export") { prepareExport() }
                    .foregroundColor(.cyan)
                    .disabled(analysis.chunks.isEmpty)
            }
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        .fileExporter(isPresented: $showExporter,
                      document: exportDocument,
                      contentType: .json,
                      defaultFilename: exportFilename) { result in
            if case .success(let url) = result {
                exportedURL = url
                showExportSuccess = true
            }
        }
        .alert("Exported", isPresented: $showExportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportedURL?.lastPathComponent ?? "File saved")
        }
        .alert("Error", isPresented: .constant(exportError != nil)) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }

    // MARK: Header stats

    private var headerBar: some View {
        HStack(spacing: 20) {
            statCell(title: "Source", value: analysis.source)
            Spacer()
            statCell(title: "Duration", value: formatTime(analysis.duration))
            statCell(title: "Chunks", value: "\(analysis.chunks.count)")
            statCell(title: "Labeled", value: "\(analysis.chunks.filter { !$0.label.isEmpty }.count)")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(white: 0.08))
    }

    private func statCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundColor(.gray)
            Text(value).font(.caption.monospaced()).foregroundColor(.white).lineLimit(1)
        }
    }

    // MARK: Timeline

    private var timelineSection: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color(white: 0.05)
                // track line
                Rectangle()
                    .fill(Color(white: 0.15))
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 34)

                ForEach(analysis.chunks) { chunk in
                    timelineChip(chunk: chunk, totalWidth: geo.size.width - 24)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 72)
        .padding(.vertical, 8)
    }

    private func timelineChip(chunk: BurstChunk, totalWidth: CGFloat) -> some View {
        let scale = totalWidth / max(analysis.duration, 0.001)
        let x = chunk.startTime * scale
        let w = max(chunk.duration * scale, 6)
        let isSelected = chunk.id == selectedChunkID
        let color: Color = chunk.label.isEmpty ? .orange : .cyan

        return RoundedRectangle(cornerRadius: 3)
            .fill(color.opacity(isSelected ? 0.9 : 0.45))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(color, lineWidth: isSelected ? 1.5 : 0))
            .frame(width: w, height: 28)
            .offset(x: x, y: 20)
            .onTapGesture { selectedChunkID = chunk.id }
    }

    // MARK: Chunk list

    private var chunkList: some View {
        List {
            ForEach($analysis.chunks) { $chunk in
                ChunkRowView(
                    chunk: $chunk,
                    totalDuration: analysis.duration,
                    isSelected: chunk.id == selectedChunkID
                )
                .listRowBackground(
                    chunk.id == selectedChunkID
                        ? Color(white: 0.13)
                        : Color(white: 0.07)
                )
                .onTapGesture { selectedChunkID = chunk.id }
            }
            .onDelete { offsets in
                analysis.chunks.remove(atOffsets: offsets)
                selectedChunkID = nil
            }
            .onMove { source, destination in
                analysis.chunks.move(fromOffsets: source, toOffset: destination)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .environment(\.editMode, .constant(.active))
    }

    // MARK: Import / Export

    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            analysis = try BurstAnalysis.load(from: url)
            selectedChunkID = nil
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func prepareExport() {
        do {
            exportData = try analysis.toJSONData()
            showExporter = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private var exportDocument: BurstAnalysisDocument? {
        guard let data = exportData else { return nil }
        return BurstAnalysisDocument(data: data)
    }

    private var exportFilename: String {
        "burst_\(analysis.source.replacingOccurrences(of: ".wav", with: "").replacingOccurrences(of: ".m4a", with: "")).json"
    }
}

// MARK: - Individual chunk row

struct ChunkRowView: View {
    @Binding var chunk: BurstChunk
    let totalDuration: Double
    let isSelected: Bool

    @FocusState private var labelFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                energyDot
                TextField("Label…", text: $chunk.label)
                    .focused($labelFocused)
                    .foregroundColor(.white)
                    .font(.body)
                    .submitLabel(.done)
                Spacer()
                durationBadge
            }

            if let tags = chunk.characteristics?.tags, !tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.gray)
                            .cornerRadius(4)
                    }
                }
            }

            if isSelected {
                trimControls
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 6)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }

    private var energyDot: some View {
        Circle()
            .fill(energyColor(chunk.characteristics?.energy ?? 0.5))
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
    }

    private var durationBadge: some View {
        Text(formatTime(chunk.duration))
            .font(.caption.monospaced())
            .foregroundColor(.cyan.opacity(0.8))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.cyan.opacity(0.12))
            .cornerRadius(4)
    }

    private var trimControls: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Start").font(.caption).foregroundColor(.gray)
                    Spacer()
                    Text(formatTime(chunk.startTime)).font(.caption.monospaced()).foregroundColor(.cyan)
                }
                Slider(value: $chunk.startTime, in: 0...(chunk.endTime - 0.01), step: 0.01)
                    .tint(.cyan)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("End").font(.caption).foregroundColor(.gray)
                    Spacer()
                    Text(formatTime(chunk.endTime)).font(.caption.monospaced()).foregroundColor(.cyan)
                }
                Slider(value: $chunk.endTime, in: (chunk.startTime + 0.01)...totalDuration, step: 0.01)
                    .tint(.cyan)
            }

            if let ch = chunk.characteristics {
                HStack(spacing: 16) {
                    if let freq = ch.dominantFrequency {
                        charCell(label: "Dominant", value: "\(Int(freq)) Hz")
                    }
                    if let energy = ch.energy {
                        charCell(label: "Energy", value: String(format: "%.0f%%", energy * 100))
                    }
                    if let centroid = ch.spectralCentroid {
                        charCell(label: "Centroid", value: "\(Int(centroid)) Hz")
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.top, 4)
    }

    private func charCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundColor(.gray)
            Text(value).font(.caption.monospaced()).foregroundColor(.white.opacity(0.7))
        }
    }

    private func energyColor(_ e: Double) -> Color {
        switch e {
        case ..<0.33: return .blue
        case ..<0.66: return .green
        default:      return .orange
        }
    }
}

// MARK: - FileDocument wrapper for system exporter

struct BurstAnalysisDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let d = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = d
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Helpers

private func formatTime(_ seconds: Double) -> String {
    if seconds >= 60 {
        let m = Int(seconds) / 60
        let s = seconds.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%05.2f", m, s)
    }
    return String(format: "%.2fs", seconds)
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BurstEditorView(analysis: .sample)
    }
    .preferredColorScheme(.dark)
}
