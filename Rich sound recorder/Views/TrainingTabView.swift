import AVFoundation
import SwiftUI

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
    @State private var availableModelVersions: [String] = []
    @State private var selectedModelVersion: String?
    @State private var selectedModelSpecs: ProjectModelSpecs?
    @State private var trainingRequestUID: String?
    @State private var trainingStatus: String?
    @State private var trainingHistory: [TrainingStatusReport] = []
    @State private var isStartingTraining = false
    @State private var isLoadingTrainingStatus = false
    @State private var isLoadingModelVersions = false
    @State private var isLoadingModelSpecs = false
    @State private var isDownloadingModel = false
    @State private var trainingError: String?
    @State private var modelVersionError: String?
    @State private var modelSpecsError: String?
    @State private var modelDownloadError: String?
    @State private var downloadedModelURL: URL?
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
    private let isProjectCountLoggingEnabled = false

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

                            if let selectedProject {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Training")
                                            .font(.headline)
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        if isLoadingTrainingStatus {
                                            ProgressView()
                                                .controlSize(.small)
                                                .tint(.cyan)
                                        }
                                    }

                                    if let trainingError {
                                        Text(trainingError)
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    }

                                    if let trainingReadinessMessage = trainingReadinessMessage(for: selectedProject) {
                                        Text(trainingReadinessMessage)
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.orange.opacity(0.12))
                                            )
                                    }

                                    Button {
                                        startTraining(for: selectedProject)
                                    } label: {
                                        HStack(spacing: 8) {
                                            if isStartingTraining {
                                                ProgressView()
                                                    .controlSize(.small)
                                                    .tint(.black)
                                            } else {
                                                Image(systemName: "cpu.fill")
                                            }
                                            Text(isStartingTraining ? "Starting Training..." : "Train Model")
                                                .font(.headline)
                                        }
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(Color.orange)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isStartingTraining || !canTrainProject(selectedProject))

                                    if let trainingStatus {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text("Status")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(.secondary)
                                                    .textCase(.uppercase)
                                                Spacer()
                                                Text(trainingStatus)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(trainingStatusColor(for: trainingStatus))
                                            }

                                            if let failureMessage = latestTrainingFailureMessage,
                                               isFailureTrainingStatus(trainingStatus) {
                                                Text(failureMessage)
                                                    .font(.caption)
                                                    .foregroundStyle(.red)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 10)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .fill(Color.red.opacity(0.12))
                                                    )
                                            }

                                            if let trainingRequestUID {
                                                Text("Request: \(trainingRequestUID)")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                    .textSelection(.enabled)
                                            }

                                            if !trainingHistory.isEmpty {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    Text("Recent Updates")
                                                        .font(.caption.weight(.semibold))
                                                        .foregroundStyle(.secondary)
                                                        .textCase(.uppercase)

                                                    ForEach(trainingHistory.prefix(3)) { report in
                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(report.status)
                                                                .font(.caption.weight(.semibold))
                                                                .foregroundStyle(.primary)

                                                            if let message = report.message, !message.isEmpty {
                                                                Text(message)
                                                                    .font(.caption2)
                                                                    .foregroundStyle(.secondary)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(Color.white.opacity(0.04))
                                        )
                                    }
                                }
                            }

                            if let selectedProject {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Trained Models")
                                            .font(.headline)
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        if isLoadingModelVersions {
                                            ProgressView()
                                                .controlSize(.small)
                                                .tint(.cyan)
                                        } else {
                                            Button {
                                                loadProjectModelVersions(forceRefresh: true)
                                            } label: {
                                                Image(systemName: "arrow.clockwise")
                                                    .foregroundStyle(.cyan)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }

                                    if let modelVersionError {
                                        Text(modelVersionError)
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    }

                                    if availableModelVersions.isEmpty {
                                        Text(isLoadingModelVersions ? "Loading trained models..." : "No trained model versions available for this project")
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
                                        Picker("Model Version", selection: $selectedModelVersion) {
                                            ForEach(availableModelVersions, id: \.self) { version in
                                                Text(version)
                                                    .tag(Optional(version))
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

                                    if let modelSpecsError {
                                        Text(modelSpecsError)
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    }

                                    if isLoadingModelSpecs {
                                        ProgressView("Loading model specs...")
                                            .tint(.cyan)
                                    } else if let selectedModelSpecs, let selectedModelVersion {
                                        VStack(alignment: .leading, spacing: 10) {
                                            Text(selectedModelVersion)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.primary)

                                            HStack(spacing: 12) {
                                                modelInfoChip(
                                                    title: "Labels",
                                                    value: "\(selectedModelSpecs.label_dict.count)"
                                                )
                                                modelInfoChip(
                                                    title: "Samples",
                                                    value: selectedModelSpecs.trained_sample_size.map(String.init) ?? "n/a"
                                                )
                                            }

                                            VStack(alignment: .leading, spacing: 6) {
                                                Text("Included Labels")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(.secondary)
                                                    .textCase(.uppercase)

                                                Text(resolvedModelLabelNames(for: selectedModelSpecs).joined(separator: ", "))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            if let modelDownloadError {
                                                Text(modelDownloadError)
                                                    .font(.caption)
                                                    .foregroundStyle(.red)
                                            }

                                            HStack(spacing: 12) {
                                                Button {
                                                    downloadIOSModel(for: selectedProject, modelVersion: selectedModelVersion, specs: selectedModelSpecs)
                                                } label: {
                                                    HStack(spacing: 8) {
                                                        if isDownloadingModel {
                                                            ProgressView()
                                                                .controlSize(.small)
                                                                .tint(.black)
                                                        } else {
                                                            Image(systemName: "arrow.down.circle.fill")
                                                        }
                                                        Text(isDownloadingModel ? "Downloading..." : "Download iOS Model")
                                                            .font(.headline)
                                                    }
                                                    .foregroundStyle(.black)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 14)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 14)
                                                            .fill(Color.green)
                                                    )
                                                }
                                                .buttonStyle(.plain)
                                                .disabled(isDownloadingModel)

                                                if let downloadedModelURL {
                                                    ShareLink(item: downloadedModelURL) {
                                                        Image(systemName: "square.and.arrow.up")
                                                            .foregroundStyle(.cyan)
                                                            .padding(14)
                                                            .background(
                                                                RoundedRectangle(cornerRadius: 14)
                                                                    .fill(Color.white.opacity(0.04))
                                                            )
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(Color.white.opacity(0.04))
                                        )
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
                resetTrainingStateForSelectedProject()
                loadProjectModelVersions()
            }
            .task(id: selectedModelVersion) {
                loadSelectedModelSpecs()
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

    private func modelInfoChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
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

    private func projectRecordingCount(for labelUID: String) -> Int {
        max(
            labelRecordingCounts[labelUID] ?? 0,
            optimisticLabelRecordingCounts[labelUID] ?? 0
        )
    }

    private func populatedProjectLabelCount(for project: Project) -> Int {
        project.labelUIDs.reduce(into: 0) { count, labelUID in
            if projectRecordingCount(for: labelUID) > 0 {
                count += 1
            }
        }
    }

    private func canTrainProject(_ project: Project) -> Bool {
        populatedProjectLabelCount(for: project) >= 2
    }

    private func trainingReadinessMessage(for project: Project) -> String? {
        let populatedLabelCount = populatedProjectLabelCount(for: project)
        guard populatedLabelCount < 2 else { return nil }
        return "Training requires recordings for at least 2 labels. Currently ready: \(populatedLabelCount)."
    }

    private var latestTrainingFailureMessage: String? {
        trainingHistory.first { report in
            isFailureTrainingStatus(report.status)
                && !(report.message?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }?.message
    }

    private func resolvedModelLabelNames(for specs: ProjectModelSpecs) -> [String] {
        let labelsByUID = Dictionary(uniqueKeysWithValues: allLabels.map { ($0.uid, $0.name) })

        let orderedEntries = specs.label_dict.sorted { lhs, rhs in
            switch (Int(lhs.key), Int(rhs.key)) {
            case let (left?, right?):
                return left < right
            default:
                return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
            }
        }

        return orderedEntries.map { key, value in
            if let labelName = labelsByUID[key] {
                return labelName
            }

            if let labelName = labelsByUID[value] {
                return labelName
            }

            return key
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

        guard let projectRepository else {
            projectLabelCountError = "Project repository unavailable"
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
                let statistics = try await projectRepository.statistics(projectUID: selectedProject.uid)
                let labelsByName = Dictionary(
                    uniqueKeysWithValues: projectLabels(for: selectedProject).map { ($0.name, $0.uid) }
                )
                var resolvedStatisticsByLabelUID: [String: Int] = [:]

                for (key, value) in statistics {
                    if selectedProject.labelUIDs.contains(key) {
                        resolvedStatisticsByLabelUID[key] = value
                    } else if let labelUID = labelsByName[key] {
                        resolvedStatisticsByLabelUID[labelUID] = value
                    }
                }

                for labelUID in labelUIDs {
                    let decodedRecordingCount = resolvedStatisticsByLabelUID[labelUID] ?? 0
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

    private func loadProjectModelVersions(forceRefresh: Bool = false) {
        guard let selectedProject else {
            availableModelVersions = []
            selectedModelVersion = nil
            selectedModelSpecs = nil
            modelVersionError = nil
            modelSpecsError = nil
            downloadedModelURL = nil
            isLoadingModelVersions = false
            return
        }

        guard let projectRepository else {
            modelVersionError = "Project repository unavailable"
            isLoadingModelVersions = false
            return
        }

        if !forceRefresh, !availableModelVersions.isEmpty {
            return
        }

        isLoadingModelVersions = true
        modelVersionError = nil
        selectedModelSpecs = nil
        modelSpecsError = nil
        downloadedModelURL = nil

        Task {
            do {
                let versions = try await projectRepository.availableModelVersions(projectUID: selectedProject.uid)
                availableModelVersions = versions

                if let selectedModelVersion,
                   versions.contains(selectedModelVersion) {
                    self.selectedModelVersion = selectedModelVersion
                } else {
                    self.selectedModelVersion = versions.first
                }
            } catch {
                availableModelVersions = []
                selectedModelVersion = nil
                modelVersionError = error.localizedDescription
            }
            isLoadingModelVersions = false
        }
    }

    private func startTraining(for project: Project) {
        guard let projectRepository else { return }

        isStartingTraining = true
        trainingError = nil

        Task {
            do {
                let request = try await projectRepository.startTraining(projectUID: project.uid)
                trainingRequestUID = request.requestUID
                await refreshTrainingStatus(for: project, requestUID: request.requestUID)
                pollTrainingStatus(for: project, requestUID: request.requestUID)
            } catch {
                trainingError = error.localizedDescription
            }
            isStartingTraining = false
        }
    }

    private func refreshTrainingStatus(for project: Project, requestUID: String) async {
        guard let projectRepository else { return }

        isLoadingTrainingStatus = true
        trainingError = nil

        do {
            let snapshot = try await projectRepository.trainingStatus(trainingRequestUID: requestUID)
            let history = try await projectRepository.trainingStatusHistory(trainingRequestUID: requestUID)
            let latestFirstHistory = orderedTrainingHistory(history)
            let resolvedStatus = resolveTrainingStatus(
                snapshotStatus: snapshot.status,
                history: latestFirstHistory
            )
            trainingStatus = resolvedStatus
            trainingHistory = latestFirstHistory

            if isTerminalTrainingStatus(resolvedStatus) {
                loadProjectModelVersions(forceRefresh: true)
            }
        } catch {
            trainingError = error.localizedDescription
        }

        isLoadingTrainingStatus = false
    }

    private func pollTrainingStatus(for project: Project, requestUID: String) {
        Task {
            for _ in 0..<30 {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard trainingRequestUID == requestUID else { return }
                await refreshTrainingStatus(for: project, requestUID: requestUID)

                if let trainingStatus, isTerminalTrainingStatus(trainingStatus) {
                    return
                }
            }
        }
    }

    private func resetTrainingStateForSelectedProject() {
        trainingRequestUID = nil
        trainingStatus = nil
        trainingHistory = []
        trainingError = nil
        isLoadingTrainingStatus = false
        isStartingTraining = false
    }

    private func isTerminalTrainingStatus(_ status: String) -> Bool {
        let normalized = status.lowercased()
        return normalized.contains("complete")
            || normalized.contains("completed")
            || normalized.contains("success")
            || normalized.contains("failed")
            || normalized.contains("error")
    }

    private func isFailureTrainingStatus(_ status: String) -> Bool {
        let normalized = status.lowercased()
        return normalized.contains("fail") || normalized.contains("error")
    }

    private func trainingStatusColor(for status: String) -> Color {
        let normalized = status.lowercased()
        if normalized.contains("complete") || normalized.contains("success") {
            return .green
        }
        if isFailureTrainingStatus(status) {
            return .red
        }
        return .orange
    }

    private func orderedTrainingHistory(_ history: [TrainingStatusReport]) -> [TrainingStatusReport] {
        guard history.count > 1 else { return history }

        let sorted = history.sorted { lhs, rhs in
            (lhs.createdAt ?? "") > (rhs.createdAt ?? "")
        }
        return sorted
    }

    private func resolveTrainingStatus(
        snapshotStatus: String,
        history: [TrainingStatusReport]
    ) -> String {
        let trimmedSnapshot = snapshotStatus.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSnapshot = trimmedSnapshot.lowercased()

        if trimmedSnapshot.isEmpty
            || normalizedSnapshot == "missing"
            || normalizedSnapshot == "status missing" {
            if let historyStatus = history.first?.status.trimmingCharacters(in: .whitespacesAndNewlines),
               !historyStatus.isEmpty {
                return historyStatus
            }
            return "Queued"
        }

        return trimmedSnapshot
    }

    private func loadSelectedModelSpecs() {
        guard let selectedProject,
              let selectedModelVersion,
              let projectRepository else {
            selectedModelSpecs = nil
            modelSpecsError = nil
            isLoadingModelSpecs = false
            return
        }

        isLoadingModelSpecs = true
        modelSpecsError = nil
        downloadedModelURL = nil

        Task {
            do {
                selectedModelSpecs = try await projectRepository.modelSpecs(
                    projectUID: selectedProject.uid,
                    modelVersion: selectedModelVersion
                )
            } catch {
                selectedModelSpecs = nil
                modelSpecsError = error.localizedDescription
            }
            isLoadingModelSpecs = false
        }
    }

    private func downloadIOSModel(for project: Project, modelVersion: String, specs: ProjectModelSpecs) {
        guard let projectRepository else { return }

        isDownloadingModel = true
        modelDownloadError = nil
        downloadedModelURL = nil

        let samplingRate = 16_000
        let inputNSamples = max(specs.trained_sample_size ?? samplingRate, 1)

        Task {
            do {
                downloadedModelURL = try await projectRepository.downloadIOSModel(
                    projectUID: project.uid,
                    modelVersion: modelVersion,
                    samplingRate: samplingRate,
                    inputNSamples: inputNSamples,
                    displayName: "\(project.name) v\(modelVersion)",
                    labelNames: resolvedModelLabelNames(for: specs)
                )
            } catch {
                modelDownloadError = error.localizedDescription
            }
            isDownloadingModel = false
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
