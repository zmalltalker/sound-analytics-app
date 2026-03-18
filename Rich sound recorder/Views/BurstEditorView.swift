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
    @State private var timelineZoom: CGFloat = 1.0
    @GestureState private var pinchScale: CGFloat = 1.0

    private var effectiveZoom: CGFloat { timelineZoom * pinchScale }

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
            // baseScale fits the whole recording into the visible width at zoom 1×
            let baseScale = (geo.size.width - 24) / max(analysis.duration, 0.001)
            let scale     = baseScale * effectiveZoom
            let contentW  = max(geo.size.width, CGFloat(analysis.duration) * scale + 24)

            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Centre track line (y = 43 = half of 88pt section)
                    Rectangle()
                        .fill(Color(white: 0.15))
                        .frame(width: contentW, height: 2)
                        .offset(y: 43)

                    ForEach($analysis.chunks) { $chunk in
                        TimelineChipView(
                            chunk: $chunk,
                            scale: scale,
                            totalDuration: analysis.duration,
                            isSelected: chunk.id == selectedChunkID,
                            onSelect: { selectedChunkID = chunk.id }
                        )
                    }
                }
                .frame(width: contentW, height: 88)
                .background(Color(white: 0.05))
            }
            // Pinch-to-zoom: two fingers spread = zoom in, pinch = zoom out.
            // simultaneousGesture lets horizontal scroll work at the same time.
            .simultaneousGesture(
                MagnificationGesture()
                    .updating($pinchScale) { value, state, _ in
                        state = value
                    }
                    .onEnded { value in
                        timelineZoom = max(0.5, min(20.0, timelineZoom * value))
                    }
            )
        }
        .frame(height: 88)
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

// MARK: - Timeline chip with draggable left/right handles

struct TimelineChipView: View {
    @Binding var chunk: BurstChunk
    let scale: CGFloat          // points per second
    let totalDuration: Double
    let isSelected: Bool
    let onSelect: () -> Void

    private let handleW: CGFloat = 14
    private let chipH: CGFloat  = 36
    private let minDur: Double  = 0.02

    // Anchor times captured at the start of each drag so we compute a clean delta
    @State private var leftAnchor: Double?  = nil
    @State private var rightAnchor: Double? = nil

    var body: some View {
        let startX = CGFloat(chunk.startTime) * scale
        let width  = max(CGFloat(chunk.duration) * scale, handleW * 2 + 4)
        let chipY  = CGFloat(43) - chipH / 2   // vertically centred on the track line
        let color: Color = chunk.label.isEmpty ? .orange : .cyan

        ZStack(alignment: .leading) {
            // Body — tap to select
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(isSelected ? 0.35 : 0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(color.opacity(isSelected ? 0.9 : 0.45), lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onTapGesture { onSelect() }

            // Left handle — drag to move startTime
            handlePill(color: color)
                .frame(maxHeight: .infinity, alignment: .leading)
                .gesture(leftDragGesture)

            // Right handle — drag to move endTime
            handlePill(color: color)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .gesture(rightDragGesture)
        }
        .frame(width: width, height: chipH)
        .offset(x: startX, y: chipY)
    }

    // A rounded pill with a small white grip line in the centre
    private func handlePill(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color.opacity(0.8))
            .frame(width: handleW)
            .overlay(
                Capsule()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 2, height: chipH * 0.42)
            )
    }

    private var leftDragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if leftAnchor == nil { leftAnchor = chunk.startTime }
                let dt = Double(value.translation.width / scale)
                chunk.startTime = max(0, min(chunk.endTime - minDur, leftAnchor! + dt))
            }
            .onEnded { _ in leftAnchor = nil }
    }

    private var rightDragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if rightAnchor == nil { rightAnchor = chunk.endTime }
                let dt = Double(value.translation.width / scale)
                chunk.endTime = max(chunk.startTime + minDur, min(totalDuration, rightAnchor! + dt))
            }
            .onEnded { _ in rightAnchor = nil }
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
