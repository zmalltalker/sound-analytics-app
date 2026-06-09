//
//  MainView.swift
//  Rich sound recorder
//
//  Created by Marius Mathiesen on 17/03/2026.
//

import AVFoundation
import CoreML
import SoundAnalysis
import SwiftUI

struct DetectionModelDescriptor: Identifiable, Hashable {
    let id: String
    let displayName: String
    let summary: String
    let bundledModelName: String?
}

struct DetectionEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let startTime: Double
    let endTime: Double
    let confidence: Double

    var timeRange: String {
        "\(Self.formatTime(startTime)) - \(Self.formatTime(endTime))"
    }

    private static func formatTime(_ value: Double) -> String {
        let totalSeconds = max(0, Int(value.rounded(.down)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

protocol DetectionModelProviding {
    func availableModels() async throws -> [DetectionModelDescriptor]
}

protocol EventDetectionServicing {
    func recognizeEvents(
        in recording: CompletedRecording,
        model: DetectionModelDescriptor
    ) async throws -> [DetectionEvent]
}

struct MockDetectionModelProvider: DetectionModelProviding {
    func availableModels() async throws -> [DetectionModelDescriptor] {
        [
            DetectionModelDescriptor(
                id: "baseline-acoustic-v1",
                displayName: "Baseline Acoustic v1",
                summary: "Fast general-purpose detector",
                bundledModelName: nil
            ),
            DetectionModelDescriptor(
                id: "urban-events-v2",
                displayName: "Urban Events v2",
                summary: "Placeholder traffic and city event model",
                bundledModelName: nil
            ),
            DetectionModelDescriptor(
                id: "industrial-watch-v1",
                displayName: "Industrial Watch v1",
                summary: "Placeholder machine anomaly model",
                bundledModelName: nil
            )
        ]
    }
}

struct MockEventDetectionService: EventDetectionServicing {
    func recognizeEvents(
        in recording: CompletedRecording,
        model: DetectionModelDescriptor
    ) async throws -> [DetectionEvent] {
        try await Task.sleep(for: .milliseconds(700))

        let clipName = recording.fileURL.deletingPathExtension().lastPathComponent
        let duration = max(recording.audioEndTimestamp, 3)
        let earlyEnd = min(max(duration * 0.22, 1.2), max(duration - 0.8, 1.4))
        let middleStart = min(max(duration * 0.34, 1.4), max(duration - 1.2, 1.6))
        let middleEnd = min(max(duration * 0.63, middleStart + 0.8), max(duration - 0.4, middleStart + 0.9))
        let lateStart = min(max(duration * 0.74, middleEnd + 0.15), max(duration - 1.0, middleEnd + 0.2))
        let lateEnd = min(duration, max(duration * 0.94, lateStart + 0.5))

        return [
            DetectionEvent(
                id: "\(model.id)-1",
                title: "Transient event in \(clipName)",
                startTime: 0.15,
                endTime: earlyEnd,
                confidence: 0.94
            ),
            DetectionEvent(
                id: "\(model.id)-2",
                title: "Sustained pattern",
                startTime: middleStart,
                endTime: middleEnd,
                confidence: 0.81
            ),
            DetectionEvent(
                id: "\(model.id)-3",
                title: "Background activity",
                startTime: lateStart,
                endTime: lateEnd,
                confidence: 0.67
            )
        ]
    }
}

enum LocalSoundDetectionError: LocalizedError {
    case missingBundledModel
    case unsupportedModelSelection
    case noResultsProduced

    var errorDescription: String? {
        switch self {
        case .missingBundledModel:
            return "The bundled sound classifier could not be found in the app bundle."
        case .unsupportedModelSelection:
            return "The selected model is not backed by a bundled classifier."
        case .noResultsProduced:
            return "The classifier did not return any sound events for this recording."
        }
    }
}

struct BundledDetectionModelProvider: DetectionModelProviding {
    func availableModels() async throws -> [DetectionModelDescriptor] {
        let bundledModels = [
            DetectionModelDescriptor(
                id: "demo-sound-classifier-1",
                displayName: "Demo sound classifier 1",
                summary: "Create ML classifier trained on DATASEC with 22 environmental sound classes",
                bundledModelName: "Demo sound classifier 1"
            ),
            DetectionModelDescriptor(
                id: "my-sound-classifier-1",
                displayName: "MySoundClassifier 1",
                summary: "Bundled Create ML drone-focused sound classifier",
                bundledModelName: "MySoundClassifier 1"
            )
        ].filter { model in
            guard let bundledModelName = model.bundledModelName else { return false }
            return Bundle.main.url(forResource: bundledModelName, withExtension: "mlmodelc") != nil
        }

        return bundledModels.isEmpty ? try await MockDetectionModelProvider().availableModels() : bundledModels
    }
}

struct BundledEventDetectionService: EventDetectionServicing {
    let fallbackService: any EventDetectionServicing

    init(fallbackService: any EventDetectionServicing = MockEventDetectionService()) {
        self.fallbackService = fallbackService
    }

    func recognizeEvents(
        in recording: CompletedRecording,
        model: DetectionModelDescriptor
    ) async throws -> [DetectionEvent] {
        guard let bundledModelName = model.bundledModelName else {
            return try await fallbackService.recognizeEvents(in: recording, model: model)
        }

        guard let modelURL = Bundle.main.url(forResource: bundledModelName, withExtension: "mlmodelc") else {
            return try await fallbackService.recognizeEvents(in: recording, model: model)
        }

        let mlModel = try MLModel(contentsOf: modelURL)
        let request = try SNClassifySoundRequest(mlModel: mlModel)
        let analyzer = try SNAudioFileAnalyzer(url: recording.fileURL)
        let observer = FileSoundAnalysisObserver()

        return try await withCheckedThrowingContinuation { continuation in
            observer.onFinish = {
                let events = observer.makeEvents()

                if events.isEmpty {
                    continuation.resume(throwing: LocalSoundDetectionError.noResultsProduced)
                } else {
                    continuation.resume(returning: events)
                }
            }
            observer.onError = { error in
                continuation.resume(throwing: error)
            }

            do {
                try analyzer.add(request, withObserver: observer)
                analyzer.analyze { _ in
                    observer.onFinish?()
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

final class FileSoundAnalysisObserver: NSObject, SNResultsObserving {
    struct Observation {
        let identifier: String
        let confidence: Double
        let startTime: Double
        let endTime: Double
    }

    var onFinish: (() -> Void)?
    var onError: ((Error) -> Void)?

    private(set) var observations: [Observation] = []

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let classificationResult = result as? SNClassificationResult,
              let topClassification = classificationResult.classifications.first else { return }

        let start = classificationResult.timeRange.start.seconds
        let duration = classificationResult.timeRange.duration.seconds

        observations.append(
            Observation(
                identifier: topClassification.identifier,
                confidence: Double(topClassification.confidence),
                startTime: start,
                endTime: start + duration
            )
        )
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        onError?(error)
    }

    func makeEvents() -> [DetectionEvent] {
        let filtered = observations.filter { observation in
            observation.confidence >= 0.35 &&
            observation.identifier.caseInsensitiveCompare("background") != .orderedSame
        }

        let source = filtered.isEmpty ? observations : filtered
        guard !source.isEmpty else { return [] }

        var merged: [Observation] = []

        for observation in source.sorted(by: { $0.startTime < $1.startTime }) {
            if let last = merged.last,
               last.identifier == observation.identifier,
               observation.startTime - last.endTime < 0.35 {
                merged[merged.count - 1] = Observation(
                    identifier: last.identifier,
                    confidence: max(last.confidence, observation.confidence),
                    startTime: last.startTime,
                    endTime: max(last.endTime, observation.endTime)
                )
            } else {
                merged.append(observation)
            }
        }

        return merged.enumerated().map { index, observation in
            DetectionEvent(
                id: "\(observation.identifier)-\(index)",
                title: observation.identifier,
                startTime: observation.startTime,
                endTime: observation.endTime,
                confidence: observation.confidence
            )
        }
    }
}

struct WaveformLoader {
    func loadSamples(from fileURL: URL, sampleCount: Int = 120) throws -> [Double] {
        let audioFile = try AVAudioFile(forReading: fileURL)
        let frameCount = AVAudioFrameCount(audioFile.length)

        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameCount) else {
            return []
        }

        try audioFile.read(into: buffer)

        guard let channelData = buffer.floatChannelData else {
            return []
        }

        let channelCount = Int(audioFile.processingFormat.channelCount)
        let sampleTotal = Int(buffer.frameLength)
        let bucketSize = max(1, sampleTotal / sampleCount)
        var peaks: [Double] = []
        peaks.reserveCapacity(sampleCount)

        for bucketStart in stride(from: 0, to: sampleTotal, by: bucketSize) {
            let bucketEnd = min(bucketStart + bucketSize, sampleTotal)
            var peak: Float = 0

            for frame in bucketStart..<bucketEnd {
                var mixedSample: Float = 0

                for channel in 0..<channelCount {
                    mixedSample += abs(channelData[channel][frame])
                }

                peak = max(peak, mixedSample / Float(channelCount))
            }

            peaks.append(Double(peak))
        }

        guard let maxPeak = peaks.max(), maxPeak > 0 else {
            return Array(repeating: 0.05, count: peaks.count)
        }

        return peaks.map { max(0.04, $0 / maxPeak) }
    }
}

struct MainView: View {
    let loginService: AuthenticationService
    let detectionService: any EventDetectionServicing
    let detectionModelProvider: any DetectionModelProviding
    @State private var showProfileSheet = false

    init(
        loginService: AuthenticationService,
        detectionService: any EventDetectionServicing = BundledEventDetectionService(),
        detectionModelProvider: any DetectionModelProviding = BundledDetectionModelProvider()
    ) {
        self.loginService = loginService
        self.detectionService = detectionService
        self.detectionModelProvider = detectionModelProvider
    }

    var body: some View {
        TabView {
            TrainingTab(loginService: loginService, showProfileSheet: $showProfileSheet)
                .tabItem {
                    Label("Training", systemImage: "waveform")
                }

            DetectionTab(
                showProfileSheet: $showProfileSheet,
                detectionService: detectionService,
                modelProvider: detectionModelProvider
            )
                .tabItem {
                    Label("Detection", systemImage: "dot.scope")
                }

            MoreTab(loginService: loginService, showProfileSheet: $showProfileSheet)
                .tabItem {
                    Label("More", systemImage: "square.grid.2x2")
                }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showProfileSheet) {
            ProfileSheet(loginService: loginService)
        }
    }
}

// MARK: - Projects Tab

struct ProjectsTab: View {
    let loginService: AuthenticationService
    @Binding var showProfileSheet: Bool
    let wrapInNavigation: Bool

    @State private var repository: ProjectRepository?
    @State private var labelRepository: LabelRepository?
    @State private var projects: [Project] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showNewProjectSheet = false

    init(
        loginService: AuthenticationService,
        showProfileSheet: Binding<Bool>,
        wrapInNavigation: Bool = true
    ) {
        self.loginService = loginService
        _showProfileSheet = showProfileSheet
        self.wrapInNavigation = wrapInNavigation
    }

    var body: some View {
        Group {
            if wrapInNavigation {
                NavigationStack {
                    content
                }
            } else {
                content
            }
        }
    }

    private var content: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                if isLoading {
                    ProgressView()
                        .tint(.cyan)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(.red.opacity(0.7))
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Button("Retry") { fetchProjects() }
                            .foregroundStyle(.cyan)
                    }
                } else if projects.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "folder")
                            .font(.system(size: 40))
                            .foregroundStyle(.cyan.opacity(0.5))
                        Text("No projects found")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        ForEach(projects) { project in
                            ProjectListRow(
                                project: project,
                                projectRepository: repository,
                                labelRepository: labelRepository
                            ) { updatedProject in
                                replaceProject(updatedProject)
                            }
                            .listRowBackground(Color.white.opacity(0.06))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteProject(project)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Projects")
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
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showNewProjectSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.cyan)
                }
            }
        }
        .sheet(isPresented: $showNewProjectSheet) {
            if let repository {
                NewProjectSheet(repository: repository) {
                    fetchProjects()
                }
            }
        }
        .task {
            repository = ProjectRepository(loginService: loginService)
            labelRepository = LabelRepository(loginService: loginService)
            fetchProjects()
        }
    }

    private func deleteProject(_ project: Project) {
        guard let repository else { return }
        projects.removeAll { $0.id == project.id }
        Task {
            do {
                try await repository.delete(project)
            } catch {
                projects.append(project)
                errorMessage = error.localizedDescription
            }
        }
    }

    private func fetchProjects() {
        guard let repository else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                projects = try await repository.list()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func replaceProject(_ project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index] = project
    }
}

struct ProjectListRow: View {
    let project: Project
    let projectRepository: ProjectRepository?
    let labelRepository: LabelRepository?
    let onProjectUpdated: (Project) -> Void

    var body: some View {
        if let projectRepository, let labelRepository {
            NavigationLink {
                ProjectDetailView(
                    project: project,
                    projectRepository: projectRepository,
                    labelRepository: labelRepository,
                    onProjectUpdated: onProjectUpdated
                )
            } label: {
                ProjectRow(project: project)
            }
        } else {
            ProjectRow(project: project)
        }
    }
}

struct ProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.name)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)

            if !project.description.isEmpty {
                Text(project.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("\(project.labelUIDs.count) label\(project.labelUIDs.count == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundStyle(.cyan)
        }
    }
}

struct ProjectDetailView: View {
    let projectRepository: ProjectRepository
    let labelRepository: LabelRepository
    let onProjectUpdated: (Project) -> Void

    @State private var project: Project
    @State private var availableLabels: [RecorderLabel] = []
    @State private var isLoadingLabels = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    init(
        project: Project,
        projectRepository: ProjectRepository,
        labelRepository: LabelRepository,
        onProjectUpdated: @escaping (Project) -> Void
    ) {
        self.projectRepository = projectRepository
        self.labelRepository = labelRepository
        self.onProjectUpdated = onProjectUpdated
        _project = State(initialValue: project)
    }

    var body: some View {
        List {
            Section("Project") {
                LabeledContent("Name", value: project.name)
                LabeledContent("Description", value: project.description.isEmpty ? "No description" : project.description)
                LabeledContent("Assigned Labels", value: "\(project.labelUIDs.count)")
            }
            .listRowBackground(Color.white.opacity(0.06))

            if let successMessage {
                Section {
                    Text(successMessage)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .listRowBackground(Color.green.opacity(0.12))
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .listRowBackground(Color.red.opacity(0.12))
            }

            Section("Labels") {
                if isLoadingLabels {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(.cyan)
                        Spacer()
                    }
                } else if availableLabels.isEmpty {
                    Text("No labels available")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(availableLabels) { label in
                        LabelAssignmentRow(
                            label: label,
                            isAssigned: project.labelUIDs.contains(label.uid),
                            isSaving: isSaving,
                            onAssign: { assign(label) }
                        )
                    }
                }
            }
            .listRowBackground(Color.white.opacity(0.06))
        }
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await loadLabels()
        }
    }

    private func loadLabels() async {
        isLoadingLabels = true
        errorMessage = nil

        do {
            availableLabels = try await labelRepository.list()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingLabels = false
    }

    private func assign(_ label: RecorderLabel) {
        guard !project.labelUIDs.contains(label.uid) else { return }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        Task {
            let updatedLabelUIDs = project.labelUIDs + [label.uid]

            do {
                try await projectRepository.addLabels(projectUID: project.uid, labelUIDs: [label.uid])
                let updatedProject = Project(
                    uid: project.uid,
                    name: project.name,
                    description: project.description,
                    owner_uid: project.owner_uid,
                    labels: encodedArray(updatedLabelUIDs),
                    guests_uids: project.guests_uids,
                    input_download_response: project.input_download_response
                )
                project = updatedProject
                onProjectUpdated(updatedProject)
                successMessage = "\"\(label.name)\" assigned"
            } catch {
                errorMessage = error.localizedDescription
            }

            isSaving = false
        }
    }

    private func encodedArray(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
}

struct LabelAssignmentRow: View {
    let label: RecorderLabel
    let isAssigned: Bool
    let isSaving: Bool
    let onAssign: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label.name)
                    .foregroundStyle(.primary)

                if !label.description.isEmpty {
                    Text(label.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isAssigned {
                Label("Assigned", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
            } else if isSaving {
                ProgressView()
                    .tint(.cyan)
            } else {
                Button("Assign", action: onAssign)
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - New Project Sheet

struct NewProjectSheet: View {
    let repository: ProjectRepository
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                Form {
                    Section {
                        TextField("Name", text: $name)
                        TextField("Description", text: $description)
                    }
                    .listRowBackground(Color.white.opacity(0.06))

                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                        .listRowBackground(Color.red.opacity(0.1))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.cyan)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView().tint(.cyan)
                    } else {
                        Button("Create") { createProject() }
                            .foregroundStyle(.cyan)
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium])
    }

    private func createProject() {
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                try await repository.create(
                    name: name.trimmingCharacters(in: .whitespaces),
                    description: description.trimmingCharacters(in: .whitespaces)
                )
                onCreated()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

// MARK: - Labels Tab

struct LabelsTab: View {
    let loginService: AuthenticationService
    @Binding var showProfileSheet: Bool
    let wrapInNavigation: Bool

    @State private var repository: LabelRepository?
    @State private var labels: [RecorderLabel] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showNewLabelSheet = false

    init(
        loginService: AuthenticationService,
        showProfileSheet: Binding<Bool>,
        wrapInNavigation: Bool = true
    ) {
        self.loginService = loginService
        _showProfileSheet = showProfileSheet
        self.wrapInNavigation = wrapInNavigation
    }

    var body: some View {
        Group {
            if wrapInNavigation {
                NavigationStack {
                    content
                }
            } else {
                content
            }
        }
    }

    private var content: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                if isLoading {
                    ProgressView()
                        .tint(.cyan)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(.red.opacity(0.7))
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Button("Retry") { fetchLabels() }
                            .foregroundStyle(.cyan)
                    }
                } else if labels.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tag")
                            .font(.system(size: 40))
                            .foregroundStyle(.cyan.opacity(0.5))
                        Text("No labels found")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List(labels) { label in
                        Text(label.name)
                            .listRowBackground(Color.white.opacity(0.06))
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Labels")
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
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showNewLabelSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.cyan)
                }
            }
        }
        .sheet(isPresented: $showNewLabelSheet) {
            if let repository {
                NewLabelSheet(repository: repository) {
                    fetchLabels()
                }
            }
        }
        .task {
            repository = LabelRepository(loginService: loginService)
            fetchLabels()
        }
    }

    private func fetchLabels() {
        guard let repository else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                labels = try await repository.list()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - New Label Sheet

struct NewLabelSheet: View {
    let repository: LabelRepository
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var durationSeconds = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                Form {
                    Section {
                        TextField("Name", text: $name)
                        TextField("Description", text: $description)
                        TextField("Duration (seconds)", text: $durationSeconds)
                            .keyboardType(.decimalPad)
                    }
                    .listRowBackground(Color.white.opacity(0.06))

                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                        .listRowBackground(Color.red.opacity(0.1))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.cyan)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView().tint(.cyan)
                    } else {
                        Button("Create") { createLabel() }
                            .foregroundStyle(.cyan)
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium])
    }

    private func createLabel() {
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                try await repository.create(
                    name: name.trimmingCharacters(in: .whitespaces),
                    description: description.trimmingCharacters(in: .whitespaces),
                    durationSeconds: Double(durationSeconds) ?? 0
                )
                onCreated()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

// MARK: - Training Tab

struct TrainingTab: View {
    let loginService: AuthenticationService
    @Binding var showProfileSheet: Bool

    @State private var projectRepository: ProjectRepository?
    private let repository: RecordingRepository
    private let listRepository: RecordingListRepository
    private let labelRepository: LabelRepository
    private let wavExportService = RecordingWAVExportService()
    @State private var projects: [Project] = []
    @State private var allLabels: [RecorderLabel] = []
    @State private var isLoadingProjects = false
    @State private var projectLoadingError: String?
    @State private var selectedProjectUID: String?
    @State private var labelRecordingCounts: [String: Int] = [:]
    @State private var optimisticLabelRecordingCounts: [String: Int] = [:]
    @State private var isLoadingProjectLabelCounts = false
    @State private var projectLabelCountError: String?
    @State private var projectLabelCountsRevision = 0
    @State private var lastRecordingURL: URL?
    @State private var pendingRecording: CompletedRecording?
    @State private var availableLabels: [RecorderLabel] = []
    @State private var isLoadingLabels = false
    @State private var labelLoadingError: String?
    @State private var selectedLabelUID: String?
    @State private var showUploadSheet = false
    @State private var isUploading = false
    @State private var uploadMessage: String?
    @State private var uploadError: String?
    @State private var clips: [RecordingClipGroup] = []
    @State private var isLoadingClips = false
    @State private var clipsError: String?
    @State private var exportMessage: String?
    @State private var exportError: String?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var selectedClipGroup: RecordingClipGroup?
    @State private var showHistorySheet = false
    @State private var showRecordingView = false
    private let isProjectCountLoggingEnabled = true

    init(loginService: AuthenticationService, showProfileSheet: Binding<Bool>) {
        self.loginService = loginService
        _showProfileSheet = showProfileSheet
        repository = RecordingRepository(loginService: loginService)
        listRepository = RecordingListRepository(loginService: loginService)
        labelRepository = LabelRepository(loginService: loginService)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                List {
                    Section {
                        VStack(spacing: 20) {
                            VStack(spacing: 12) {
                                Image(systemName: "waveform.circle.fill")
                                    .font(.system(size: 72))
                                    .foregroundStyle(.cyan)

                                Text("Audio Recordings")
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(.primary)

                                Text("Record, label, upload, and browse clips from the API")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }

                            Button {
                                showRecordingView = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "mic.fill")
                                        .font(.title3)
                                    Text("Start Recording")
                                        .font(.headline)
                                }
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.cyan)
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                showHistorySheet = true
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "clock.arrow.circlepath")
                                    Text("History")
                                        .font(.headline)
                                }
                                .foregroundStyle(.cyan)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.cyan.opacity(0.6), lineWidth: 1)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(Color.white.opacity(0.04))
                                        )
                                )
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Project")
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if isLoadingProjects {
                                        ProgressView()
                                            .controlSize(.small)
                                            .tint(.cyan)
                                    } else {
                                        Button {
                                            loadProjects()
                                        } label: {
                                            Image(systemName: "arrow.clockwise")
                                                .foregroundStyle(.cyan)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                if let projectLoadingError {
                                    Text(projectLoadingError)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }

                                if projects.isEmpty {
                                    Text(isLoadingProjects ? "Loading projects..." : "No projects available")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(Color.white.opacity(0.04))
                                        )
                                } else {
                                    Picker("Project", selection: $selectedProjectUID) {
                                        ForEach(projects) { project in
                                            Text(project.name)
                                                .tag(Optional(project.uid))
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(.cyan)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color.white.opacity(0.04))
                                    )
                                }
                            }

                            if let selectedProject {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Project Labels")
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    if let projectLabelCountError {
                                        Text(projectLabelCountError)
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    }

                                    if selectedProject.labelUIDs.isEmpty {
                                        Text("No labels assigned to this project")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 14)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .fill(Color.white.opacity(0.04))
                                            )
                                    } else {
                                        VStack(spacing: 10) {
                                            ForEach(projectLabels(for: selectedProject)) { label in
                                                projectLabelRow(label: label)
                                            }
                                        }
                                        .id(projectLabelCountsRevision)
                                    }
                                }
                            }

                            if isUploading {
                                ProgressView("Uploading recording...")
                                    .tint(.cyan)
                            }

                            if let uploadMessage {
                                Text(uploadMessage)
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.green.opacity(0.12))
                                    )
                            }

                            if let uploadError {
                                Text(uploadError)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.red.opacity(0.12))
                                    )
                            }

                            if let exportMessage {
                                Text(exportMessage)
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.green.opacity(0.12))
                                    )
                            }

                            if let exportError {
                                Text(exportError)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.red.opacity(0.12))
                                    )
                            }

                            if let url = lastRecordingURL {
                                VStack(spacing: 8) {
                                    Text("Last Recording")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)

                                    Text(url.lastPathComponent)
                                        .font(.caption)
                                        .foregroundStyle(.cyan)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.white.opacity(0.08))
                                        )
                                }
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("Training")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(isPresented: $showRecordingView) {
                RecordingView { recording in
                    handleCompletedRecording(recording)
                }
            }
            .task {
                projectRepository = ProjectRepository(loginService: loginService)
                loadAllLabels()
                loadProjects()
                loadClips()
            }
            .task(id: selectedProjectUID) {
                loadSelectedProjectLabelCounts()
            }
            .sheet(isPresented: $showUploadSheet) {
                UploadLabelSheet(
                    fileURL: pendingRecording?.fileURL,
                    labels: availableLabels,
                    isLoadingLabels: isLoadingLabels,
                    labelLoadingError: labelLoadingError,
                    selectedLabelUID: $selectedLabelUID,
                    isUploading: isUploading,
                    onCancel: {
                        showUploadSheet = false
                        pendingRecording = nil
                    },
                    onRetry: {
                        loadLabelsForUpload()
                    },
                    onUpload: {
                        uploadPendingRecording()
                    }
                )
            }
            .sheet(isPresented: $showHistorySheet) {
                TrainingHistorySheet(
                    clips: clips,
                    isLoadingClips: isLoadingClips,
                    clipsError: clipsError,
                    onRefresh: loadClips,
                    onSelectClipGroup: { clipGroup in
                        selectedClipGroup = clipGroup
                    }
                )
            }
            .sheet(item: $selectedClipGroup) { clipGroup in
                RecordingVersionsSheet(
                    clipGroup: clipGroup,
                    onExport: { clip in
                        exportWAV(for: clip)
                    },
                    onPlay: { clip in
                        playClip(clip)
                    }
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        loadClips()
                    } label: {
                        Image(systemName: "arrow.clockwise")
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
        }
    }

    private func handleCompletedRecording(_ recording: CompletedRecording) {
        lastRecordingURL = recording.fileURL
        pendingRecording = recording
        uploadMessage = nil
        uploadError = nil
        labelLoadingError = nil
        availableLabels = []
        showUploadSheet = true
        loadLabelsForUpload()
    }

    private var selectedProject: Project? {
        guard let selectedProjectUID else { return nil }
        return projects.first(where: { $0.uid == selectedProjectUID })
    }

    private func projectLabelRow(label: RecorderLabel) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if !label.description.isEmpty {
                    Text(label.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Text(labelRecordingCountText(for: label.uid))
                .font(.headline.monospacedDigit())
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
    }

    private func projectLabels(for project: Project) -> [RecorderLabel] {
        let labelsByUID = Dictionary(uniqueKeysWithValues: allLabels.map { ($0.uid, $0) })
        return project.labelUIDs.map { labelUID in
            labelsByUID[labelUID] ?? RecorderLabel(
                uid: labelUID,
                guid: labelUID,
                name: labelUID,
                user_id: "",
                duration: 0,
                description: ""
            )
        }
    }

    private func loadAllLabels() {
        Task {
            do {
                allLabels = try await labelRepository.list()
            } catch {
                if projectLabelCountError == nil {
                    projectLabelCountError = error.localizedDescription
                }
            }
        }
    }

    private func loadProjects() {
        guard let projectRepository else { return }

        isLoadingProjects = true
        projectLoadingError = nil

        Task {
            do {
                let loadedProjects = try await projectRepository.list()
                projects = loadedProjects

                if let selectedProjectUID,
                   loadedProjects.contains(where: { $0.uid == selectedProjectUID }) {
                    self.selectedProjectUID = selectedProjectUID
                } else {
                    self.selectedProjectUID = loadedProjects.first?.uid
                }
            } catch {
                projectLoadingError = error.localizedDescription
            }
            isLoadingProjects = false
        }
    }

    private func loadSelectedProjectLabelCounts(forceRefresh: Bool = false) {
        guard let selectedProject else {
            projectLabelCountError = nil
            isLoadingProjectLabelCounts = false
            return
        }

        let labelUIDs = selectedProject.labelUIDs

        if !forceRefresh, !labelUIDs.isEmpty,
           labelUIDs.allSatisfy({ labelRecordingCounts[$0] != nil }) {
            projectLabelCountError = nil
            isLoadingProjectLabelCounts = false
            return
        }

        guard !labelUIDs.isEmpty else {
            projectLabelCountError = nil
            isLoadingProjectLabelCounts = false
            return
        }

        isLoadingProjectLabelCounts = true
        projectLabelCountError = nil

        Task {
            do {
                for labelUID in labelUIDs {
                    let clipGroups = try await listRepository.list(labelUID: labelUID)
                    let decodedRecordingCount = clipGroups.reduce(0) { $0 + $1.versions.count }
                    let resolvedCount = max(
                        decodedRecordingCount,
                        optimisticLabelRecordingCounts[labelUID] ?? 0
                    )
                    setLabelRecordingCount(resolvedCount, for: labelUID)
                    logProjectCount(
                        "resolved",
                        projectUID: selectedProject.uid,
                        labelUID: labelUID,
                        decodedRecordingCount: decodedRecordingCount,
                        displayedCount: resolvedCount
                    )
                }
            } catch {
                projectLabelCountError = error.localizedDescription
                logProjectCount(
                    "failed",
                    projectUID: selectedProject.uid,
                    labelUID: nil,
                    decodedRecordingCount: nil,
                    displayedCount: nil,
                    error: error.localizedDescription
                )
            }
            isLoadingProjectLabelCounts = false
        }
    }

    private func labelRecordingCountText(for labelUID: String) -> String {
        if isLoadingProjectLabelCounts && labelRecordingCounts[labelUID] == nil {
            return "Loading..."
        }

        let count = max(
            labelRecordingCounts[labelUID] ?? 0,
            optimisticLabelRecordingCounts[labelUID] ?? 0
        )
        return String(count)
    }

    private func registerSuccessfulUpload(forLabelUID labelUID: String) {
        let affectedProjectUIDs = projects
            .filter { $0.labelUIDs.contains(labelUID) }
            .map(\.uid)

        if !affectedProjectUIDs.isEmpty {
            let currentCount = max(
                labelRecordingCounts[labelUID] ?? 0,
                optimisticLabelRecordingCounts[labelUID] ?? 0
            )
            let updatedCount = currentCount + 1
            setOptimisticLabelRecordingCount(updatedCount, for: labelUID)
            setLabelRecordingCount(updatedCount, for: labelUID)
            logProjectCount(
                "optimistic+1",
                projectUID: affectedProjectUIDs[0],
                labelUID: labelUID,
                decodedRecordingCount: currentCount,
                displayedCount: updatedCount
            )
        }

        if let selectedProjectUID, affectedProjectUIDs.contains(selectedProjectUID) {
            loadSelectedProjectLabelCounts(forceRefresh: true)
            Task {
                try? await Task.sleep(nanoseconds: 750_000_000)
                loadSelectedProjectLabelCounts(forceRefresh: true)
            }
        }
    }

    private func setLabelRecordingCount(_ count: Int, for labelUID: String) {
        var updatedCounts = labelRecordingCounts
        updatedCounts[labelUID] = count
        labelRecordingCounts = updatedCounts
        projectLabelCountsRevision += 1
    }

    private func setOptimisticLabelRecordingCount(_ count: Int, for labelUID: String) {
        var updatedCounts = optimisticLabelRecordingCounts
        updatedCounts[labelUID] = count
        optimisticLabelRecordingCounts = updatedCounts
    }

    private func logProjectCount(
        _ phase: String,
        projectUID: String,
        labelUID: String?,
        decodedRecordingCount: Int?,
        displayedCount: Int?,
        error: String? = nil
    ) {
        guard isProjectCountLoggingEnabled else { return }

        var parts: [String] = ["Project count \(phase)", "project=\(projectUID)"]
        if let labelUID {
            parts.append("label=\(labelUID)")
        }
        if let decodedRecordingCount {
            parts.append("decodedCount=\(decodedRecordingCount)")
        }
        if let displayedCount {
            parts.append("displayed=\(displayedCount)")
        }
        if let error {
            parts.append("error=\(error)")
        }

        print(parts.joined(separator: " | "))
    }

    private func loadLabelsForUpload() {
        isLoadingLabels = true
        labelLoadingError = nil

        Task {
            do {
                let labels = try await labelRepository.list()
                let filteredLabels: [RecorderLabel]

                if let selectedProject {
                    let allowedLabelUIDs = Set(selectedProject.labelUIDs)
                    filteredLabels = labels.filter { allowedLabelUIDs.contains($0.uid) }
                } else {
                    filteredLabels = labels
                }

                availableLabels = filteredLabels
                if let selectedLabelUID,
                   filteredLabels.contains(where: { $0.uid == selectedLabelUID }) {
                    self.selectedLabelUID = selectedLabelUID
                } else {
                    self.selectedLabelUID = filteredLabels.first?.uid
                }
            } catch {
                labelLoadingError = error.localizedDescription
            }
            isLoadingLabels = false
        }
    }

    private func uploadPendingRecording() {
        guard let pendingRecording, let selectedLabelUID else { return }

        uploadMessage = nil
        uploadError = nil
        isUploading = true

        Task {
            do {
                try await repository.uploadRecording(recording: pendingRecording, labelUID: selectedLabelUID)
                uploadMessage = "Uploaded \(pendingRecording.fileURL.lastPathComponent)"
                showUploadSheet = false
                self.pendingRecording = nil
                registerSuccessfulUpload(forLabelUID: selectedLabelUID)
                loadClips()
            } catch {
                uploadError = error.localizedDescription
            }
            isUploading = false
        }
    }

    private func loadClips() {
        isLoadingClips = true
        clipsError = nil

        Task {
            do {
                clips = try await listRepository.list()
            } catch {
                clipsError = error.localizedDescription
            }
            isLoadingClips = false
        }
    }

    private func exportWAV(for clip: RecordingClip) {
        exportMessage = nil
        exportError = nil

        do {
            let fileURL = try wavExportService.exportWAV(for: clip)
            exportMessage = "Exported \(fileURL.lastPathComponent)"
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func playClip(_ clip: RecordingClip) {
        exportMessage = nil
        exportError = nil

        do {
            let fileURL = try wavExportService.exportWAV(for: clip)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)

            let player = try AVAudioPlayer(contentsOf: fileURL)
            player.prepareToPlay()
            player.play()

            audioPlayer = player
            exportMessage = "Playing \(fileURL.lastPathComponent)"
        } catch {
            exportError = error.localizedDescription
        }
    }
}

struct TrainingHistorySheet: View {
    let clips: [RecordingClipGroup]
    let isLoadingClips: Bool
    let clipsError: String?
    let onRefresh: () -> Void
    let onSelectClipGroup: (RecordingClipGroup) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                List {
                    Section("Previous Clips") {
                        if isLoadingClips {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .tint(.cyan)
                                Spacer()
                            }
                        } else if let clipsError {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(clipsError)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                Button("Retry", action: onRefresh)
                                    .foregroundStyle(.cyan)
                            }
                        } else if clips.isEmpty {
                            Text("No clips returned by the API")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(clips) { clipGroup in
                                RecordingClipGroupRow(clipGroup: clipGroup) {
                                    dismiss()
                                    onSelectClipGroup(clipGroup)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.cyan)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onRefresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.cyan)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Detection Tab

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
            startTimestamp: Int(startDate.timeIntervalSince1970),
            endTimestamp: Int(recordingEndedAt.timeIntervalSince1970),
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

    private let eventColors: [Color] = [.cyan, .orange, .green, .pink, .yellow]

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
                            let color = eventColors[index % eventColors.count]
                            let xStart = xPosition(for: event.startTime, width: geometry.size.width)
                            let xEnd = xPosition(for: event.endTime, width: geometry.size.width)

                            RoundedRectangle(cornerRadius: 8)
                                .fill(color.opacity(0.18))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(color.opacity(0.55), lineWidth: 1)
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
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.12))
                                )
                        }
                    }
                }
            } else {
                Text("No classified events were returned for this clip.")
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
        if let index = events.firstIndex(where: { time >= $0.startTime && time <= $0.endTime }) {
            return eventColors[index % eventColors.count]
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
        let color = eventColors[index % eventColors.count]

        return ZStack {
            Circle()
                .fill(color)
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

// MARK: - More Tab

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

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                Group {
                    if isLoadingLabels {
                        ProgressView("Loading labels...")
                            .tint(.cyan)
                    } else {
                        Form {
                            Section("Recording") {
                                Text(fileURL?.lastPathComponent ?? "Unknown file")
                                    .foregroundStyle(.primary)
                            }
                            .listRowBackground(Color.white.opacity(0.06))

                            if let labelLoadingError {
                                Section {
                                    Text(labelLoadingError)
                                        .font(.caption)
                                        .foregroundStyle(.red)

                                    Button("Retry", action: onRetry)
                                        .foregroundStyle(.cyan)
                                }
                                .listRowBackground(Color.red.opacity(0.12))
                            } else if labels.isEmpty {
                                Section {
                                    Text("No labels available")
                                        .foregroundStyle(.secondary)
                                }
                                .listRowBackground(Color.white.opacity(0.06))
                            } else {
                                Section("Select Label") {
                                    ForEach(labels) { label in
                                        Button {
                                            selectedLabelUID = label.uid
                                        } label: {
                                            HStack(spacing: 12) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(label.name)
                                                        .foregroundStyle(.primary)

                                                    if !label.description.isEmpty {
                                                        Text(label.description)
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                }

                                                Spacer()

                                                if selectedLabelUID == label.uid {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundStyle(.cyan)
                                                }
                                            }
                                        }
                                    }
                                }
                                .listRowBackground(Color.white.opacity(0.06))
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Upload Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .foregroundStyle(.cyan)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isUploading {
                        ProgressView()
                            .tint(.cyan)
                    } else {
                        Button("Upload", action: onUpload)
                            .foregroundStyle(.cyan)
                            .disabled(isLoadingLabels || labels.isEmpty || selectedLabelUID == nil || labelLoadingError != nil)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Profile Sheet

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

                        // Token Information Section
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

// MARK: - Info Row

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

#Preview {
    MainView(loginService: AuthenticationService())
}
