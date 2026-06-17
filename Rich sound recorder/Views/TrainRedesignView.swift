import AVFoundation
import SwiftUI

struct TrainWorkspaceView: View {
    @Environment(RedesignAppContext.self) private var appContext

    let loginService: AuthenticationService
    @Binding var showProjectSwitcher: Bool
    let onViewModels: () -> Void
    let onOpenLabels: () -> Void
    let onLeaveRunning: () -> Void

    private let recordingRepository: RecordingRepository
    private let projectRepository: ProjectRepository
    private let labelRepository: LabelRepository

    @State private var labelRecordingCounts: [String: Int] = [:]
    @State private var showRecordingView = false
    @State private var pendingRecording: CompletedRecording?
    @State private var availableLabels: [RecorderLabel] = []
    @State private var selectedLabelUID: String?
    @State private var showUploadSheet = false
    @State private var isLoadingLabels = false
    @State private var labelLoadingError: String?
    @State private var isUploading = false
    @State private var installError: String?
    @State private var isInstallingLatest = false

    init(
        loginService: AuthenticationService,
        showProjectSwitcher: Binding<Bool>,
        onViewModels: @escaping () -> Void,
        onOpenLabels: @escaping () -> Void,
        onLeaveRunning: @escaping () -> Void
    ) {
        self.loginService = loginService
        _showProjectSwitcher = showProjectSwitcher
        self.onViewModels = onViewModels
        self.onOpenLabels = onOpenLabels
        self.onLeaveRunning = onLeaveRunning
        self.recordingRepository = RecordingRepository(loginService: loginService)
        self.projectRepository = ProjectRepository(loginService: loginService)
        self.labelRepository = LabelRepository(loginService: loginService)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let activeProject = appContext.activeProject {
                    let projectLabels = appContext.projectLabels(for: activeProject)
                    let readyLabels = projectLabels.filter { (labelRecordingCounts[$0.uid] ?? 0) > 0 }
                    let isReady = projectLabels.count >= 2 && readyLabels.count >= 2

                    ContextHeader(
                        title: activeProject.name,
                        subtitle: latestVersionSubtitle(for: activeProject.uid),
                        onSwitch: { showProjectSwitcher = true }
                    )

                    readinessCard(
                        for: activeProject,
                        projectLabels: projectLabels,
                        readyLabels: readyLabels,
                        isReady: isReady
                    )

                    modelVersionsCard(for: activeProject, isReady: isReady)

                    if appContext.trainingProjectUID == activeProject.uid, appContext.isTrainingInProgress {
                        trainingProgressCard
                    } else if appContext.trainingProjectUID == activeProject.uid, trainingDidFail {
                        trainingFailureCard(for: activeProject)
                    } else if let latestVersion = appContext.latestKnownVersion(for: activeProject.uid),
                              hasFreshCloudVersion(latestVersion, projectUID: activeProject.uid) {
                        installCard(version: latestVersion, projectUID: activeProject.uid)
                    }
                } else {
                    InstrumentCard {
                        Text("Create a project in Settings to start training.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 80)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationDestination(isPresented: $showRecordingView) {
            RecordingView { recording in
                pendingRecording = recording
                showUploadSheet = true
                loadLabelsForUpload()
            }
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
                onRetry: { loadLabelsForUpload() },
                onUpload: { uploadPendingRecording() }
            )
        }
        .task(id: appContext.activeProjectUID) {
            guard let activeProject = appContext.activeProject else { return }
            await appContext.refreshAvailableModelVersions(for: activeProject.uid, force: true)
            await loadRecordingCounts(for: activeProject)
            if appContext.trainingProjectUID == activeProject.uid, appContext.trainingRequestUID != nil {
                await appContext.refreshTrainingStatus()
            }
            if let latestVersion = appContext.latestKnownVersion(for: activeProject.uid) {
                _ = try? await appContext.modelSpecs(projectUID: activeProject.uid, version: latestVersion)
            }
        }
    }

    private func readinessCard(
        for project: Project,
        projectLabels: [RecorderLabel],
        readyLabels: [RecorderLabel],
        isReady: Bool
    ) -> some View {
        return InstrumentCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Readiness")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    readinessBadge(isReady: isReady)
                }

                ForEach(readinessItems(for: project, labels: projectLabels, readyLabels: readyLabels), id: \.title) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.isSatisfied ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isSatisfied ? Color(red: 0.41, green: 0.80, blue: 1.0) : .secondary)

                        Text(item.title)
                            .foregroundStyle(.primary)

                        Spacer()

                        if let actionTitle = item.actionTitle {
                            Button(actionTitle) {
                            if actionTitle == "Add" {
                                showRecordingView = true
                            } else if actionTitle == "Setup" {
                                onOpenLabels()
                            }
                        }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(red: 0.41, green: 0.80, blue: 1.0))
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        showRecordingView = true
                    } label: {
                        Text("Record audio")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color(red: 0.91, green: 0.47, blue: 0.32))
                            )
                    }
                    .buttonStyle(.plain)
                }

                if let trainingError = appContext.trainingError {
                    Text(trainingError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func modelVersionsCard(for project: Project, isReady: Bool) -> some View {
        let versions = (appContext.availableModelVersionsByProject[project.uid] ?? [])
            .sorted { compareModelVersion($0, $1) == .orderedDescending }
        let blockingText = blockingReadinessText(for: project)

        return InstrumentCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Model versions")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(versions.count)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                if versions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No trained versions yet")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Record and upload labeled clips first, then start your first cloud training run from here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(versions.prefix(3)), id: \.self) { version in
                            HStack {
                                Text("v\(version)")
                                    .font(.headline.monospaced())
                                    .foregroundStyle(.primary)
                                Spacer()
                                if appContext.activeProjectInstalledModels.contains(where: { $0.version == version }) {
                                    Text("ON DEVICE")
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(Color(red: 0.41, green: 0.80, blue: 1.0))
                                } else {
                                    Text("CLOUD")
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Button {
                    startTraining(for: project)
                } label: {
                    HStack(spacing: 8) {
                        if appContext.isStartingTraining {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(versions.isEmpty ? "Train first version from uploads" : "Train new version from uploads")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!isReady || appContext.isStartingTraining)

                if !isReady, let blockingText {
                    Text(blockingText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var trainingProgressCard: some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Training continues in the cloud if you leave — come back to Train any time to check progress.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(trainingSteps, id: \.self) { step in
                    HStack(spacing: 12) {
                        Image(systemName: currentTrainingStep == step ? "record.circle.fill" : "circle")
                            .foregroundStyle(Color(red: 0.91, green: 0.47, blue: 0.32))
                        Text(step)
                            .foregroundStyle(.primary)
                    }
                }

                ProgressView(value: trainingProgressValue)
                    .tint(Color(red: 0.91, green: 0.47, blue: 0.32))

                HStack {
                    Text("~\(estimatedMinutesRemaining) min remaining")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Leave running") {
                        onLeaveRunning()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    private func trainingFailureCard(for project: Project) -> some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Training failed")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(appContext.trainingStatus ?? "The latest training run did not finish successfully.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button {
                        startTraining(for: project)
                    } label: {
                        Text("Retry")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color(red: 0.91, green: 0.47, blue: 0.32))
                            )
                    }
                    .buttonStyle(.plain)

                    Button("View in Models", action: onViewModels)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func installCard(version: String, projectUID: String) -> some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Text("v\(version)")
                        .font(.headline.monospaced())
                        .foregroundStyle(.primary)
                    Text("READY")
                        .font(.caption.monospaced())
                        .foregroundStyle(Color(red: 0.41, green: 0.80, blue: 1.0))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(red: 0.41, green: 0.80, blue: 1.0).opacity(0.12)))
                }

                Text("New model version trained")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                if let projectSpecs = appContext.modelSpecsByProjectVersion["\(projectUID)::\(version)"] {
                    metadataChips(for: projectSpecs)
                }

                if let installError {
                    Text(installError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack(spacing: 12) {
                    Button {
                        installLatestVersion(version: version, projectUID: projectUID)
                    } label: {
                        HStack {
                            if isInstallingLatest {
                                ProgressView().controlSize(.small)
                            }
                            Text("Install on this device")
                                .font(.headline)
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color(red: 0.91, green: 0.47, blue: 0.32))
                        )
                    }
                    .buttonStyle(.plain)

                    Button("View in Models", action: onViewModels)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func latestVersionSubtitle(for projectUID: String) -> String {
        guard let latestVersion = appContext.latestKnownVersion(for: projectUID) else {
            return "No model versions yet"
        }
        return "Latest: v\(latestVersion)"
    }

    private func readinessItems(for project: Project, labels: [RecorderLabel], readyLabels: [RecorderLabel]) -> [ReadinessItem] {
        if project.labelUIDs.isEmpty {
            return [ReadinessItem(title: "Assign at least 2 labels", isSatisfied: false, actionTitle: "Setup")]
        }

        var items: [ReadinessItem] = [
            ReadinessItem(title: "\(project.labelUIDs.count) labels assigned", isSatisfied: project.labelUIDs.count >= 2, actionTitle: project.labelUIDs.count >= 2 ? nil : "Add")
        ]

        items.append(contentsOf: labels.map { label in
            let count = labelRecordingCounts[label.uid] ?? 0
            return ReadinessItem(
                title: "\(label.name) · \(count) clips",
                isSatisfied: count > 0,
                actionTitle: count > 0 ? nil : "Add"
            )
        })

        if labels.count >= 2 {
            items.append(
                ReadinessItem(
                    title: "\(readyLabels.count) labels have audio",
                    isSatisfied: readyLabels.count >= 2,
                    actionTitle: readyLabels.count >= 2 ? nil : "Add"
                )
            )
        }

        return items
    }

    private func loadRecordingCounts(for project: Project) async {
        do {
            let statistics = try await projectRepository.statistics(projectUID: project.uid)
            let labelsByName = Dictionary(uniqueKeysWithValues: appContext.projectLabels(for: project).map { ($0.name, $0.uid) })
            var resolved: [String: Int] = [:]

            for labelUID in project.labelUIDs {
                resolved[labelUID] = 0
            }

            for (key, value) in statistics {
                if project.labelUIDs.contains(key) {
                    resolved[key] = value
                } else if let labelUID = labelsByName[key] {
                    resolved[labelUID] = value
                }
            }

            labelRecordingCounts = resolved
        } catch {
            appContext.trainingError = error.localizedDescription
        }
    }

    private func startTraining(for project: Project) {
        Task {
            await appContext.startTraining(for: project.uid)
        }
    }

    private func loadLabelsForUpload() {
        guard let activeProject = appContext.activeProject else { return }
        isLoadingLabels = true
        labelLoadingError = nil

        Task {
            do {
                let labels = try await labelRepository.list()
                let allowedUIDs = Set(activeProject.labelUIDs)
                let filteredLabels = labels.filter { allowedUIDs.contains($0.uid) }
                availableLabels = filteredLabels
                selectedLabelUID = filteredLabels.first?.uid
            } catch {
                labelLoadingError = error.localizedDescription
            }
            isLoadingLabels = false
        }
    }

    private func uploadPendingRecording() {
        guard let pendingRecording, let selectedLabelUID else { return }
        isUploading = true

        Task {
            do {
                try await recordingRepository.uploadRecording(recording: pendingRecording, labelUID: selectedLabelUID)
                labelRecordingCounts[selectedLabelUID, default: 0] += 1
                showUploadSheet = false
                self.pendingRecording = nil
            } catch {
                labelLoadingError = error.localizedDescription
            }
            isUploading = false
        }
    }

    private func installLatestVersion(version: String, projectUID: String) {
        isInstallingLatest = true
        installError = nil

        Task {
            do {
                try await appContext.installModel(projectUID: projectUID, version: version)
            } catch {
                installError = error.localizedDescription
            }
            isInstallingLatest = false
        }
    }

    private func hasFreshCloudVersion(_ version: String, projectUID: String) -> Bool {
        !appContext.activeProjectInstalledModels.contains(where: { $0.version == version && $0.projectUID == projectUID })
    }

    private var trainingSteps: [String] {
        ["Uploading data", "Preprocessing", "Training model", "Packaging for device"]
    }

    private var currentTrainingStep: String {
        let normalized = appContext.trainingStatus?.lowercased() ?? ""
        if normalized.contains("upload") { return trainingSteps[0] }
        if normalized.contains("pre") { return trainingSteps[1] }
        if normalized.contains("train") { return trainingSteps[2] }
        if normalized.contains("pack") || normalized.contains("complete") { return trainingSteps[3] }
        return trainingSteps[0]
    }

    private var trainingProgressValue: Double {
        Double(max(trainingSteps.firstIndex(of: currentTrainingStep) ?? 0, 0) + 1) / Double(trainingSteps.count)
    }

    private var estimatedMinutesRemaining: Int {
        max(1, (trainingSteps.count - (trainingSteps.firstIndex(of: currentTrainingStep) ?? 0)) * 2)
    }

    private var trainingDidFail: Bool {
        let normalized = appContext.trainingStatus?.lowercased() ?? ""
        return normalized.contains("fail") || normalized.contains("error")
    }

    private func readinessBadge(isReady: Bool) -> some View {
        Text(isReady ? "READY" : "NOT READY")
            .font(.caption.monospaced())
            .foregroundStyle(isReady ? Color(red: 0.41, green: 0.80, blue: 1.0) : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill((isReady ? Color(red: 0.41, green: 0.80, blue: 1.0) : Color.white).opacity(0.12))
            )
    }

    private func metadataChips(for specs: ProjectModelSpecs) -> some View {
        let chips = [
            "\(specs.label_dict.count) labels",
            "\(specs.trained_sample_size ?? 0) samples"
        ]

        return HStack(spacing: 8) {
            ForEach(chips, id: \.self) { chip in
                Text(chip)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
            }
        }
    }

    private func blockingReadinessText(for project: Project) -> String? {
        if project.labelUIDs.count < 2 {
            return "Training is blocked until the project has at least 2 labels."
        }

        let missingAudioLabels = appContext
            .projectLabels(for: project)
            .filter { (labelRecordingCounts[$0.uid] ?? 0) == 0 }
            .map(\.name)

        if let firstMissingLabel = missingAudioLabels.first {
            return "\"\(firstMissingLabel)\" has no clips yet."
        }

        return nil
    }
}

private struct ReadinessItem {
    let title: String
    let isSatisfied: Bool
    let actionTitle: String?
}
