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
    @State private var installSuccessMessage: String?
    @State private var installSuccessToken = 0
    @State private var displayedTrainingStepIndex = 0
    @State private var isHoldingCompletedTrainingState = false
    @State private var trainingStepTask: Task<Void, Never>?
    @State private var stagedTrainingRequestUID: String?
    @State private var failedTrainingHapticRequestUID: String?

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
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let activeProject = appContext.activeProject {
                        let projectLabels = appContext.projectLabels(for: activeProject)
                        let readyLabels = projectLabels.filter { (labelRecordingCounts[$0.uid] ?? 0) > 0 }
                        let isReady = projectLabels.count >= 2 && readyLabels.count >= 2

                        trainHeader
                        activeProjectCard(for: activeProject)
                        readinessSummaryCard(
                            for: activeProject,
                            projectLabels: projectLabels,
                            readyLabels: readyLabels,
                            isReady: isReady
                        )

                        if appContext.trainingProjectUID == activeProject.uid,
                           (appContext.isTrainingInProgress || isHoldingCompletedTrainingState) {
                            trainingProgressCard
                        } else if appContext.trainingProjectUID == activeProject.uid, trainingDidFail {
                            trainingFailureCard(for: activeProject)
                        } else {
                            trainingActionButton(for: activeProject, isReady: isReady)
                        }

                        recordAudioButton
                        latestVersionCard(for: activeProject)
                    } else {
                        InstrumentCard {
                            Text("Create a project in Settings to start training.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(18)
                .padding(.top, 12)
                .padding(.bottom, max(104, geo.safeAreaInsets.bottom + 80))
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationDestination(isPresented: $showRecordingView) {
            RecordingView(
                projectName: appContext.activeProject?.name
            ) { recording in
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
        .task(id: appContext.trainingRequestUID) {
            stageTrainingSequenceIfNeeded()
        }
        .task(id: appContext.trainingStatus ?? "") {
            reactToTrainingStatus()
        }
        .onDisappear {
            trainingStepTask?.cancel()
        }
        .overlay(alignment: .bottom) {
            if let installSuccessMessage {
                SuccessToast(title: installSuccessMessage)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: installSuccessToken) { _, newValue in
            guard newValue > 0 else { return }
            AppHaptics.success()
        }
    }

    private var trainHeader: some View {
        HStack {
            Text("Train")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private func activeProjectCard(for project: Project) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.28, green: 0.63, blue: 1.0),
                            Color(red: 0.10, green: 0.46, blue: 0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: "waveform")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("Active project")
                    .font(.caption.weight(.regular))
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            Spacer(minLength: 12)

            Button("Switch") {
                showProjectSwitcher = true
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color(red: 0.11, green: 0.53, blue: 0.98))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color(red: 0.10, green: 0.26, blue: 0.46).opacity(0.8))
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func readinessSummaryCard(
        for project: Project,
        projectLabels: [RecorderLabel],
        readyLabels: [RecorderLabel],
        isReady: Bool
    ) -> some View {
        let labelRows = readinessLabelRows(for: projectLabels)
        let totalClips = labelRows.reduce(0) { $0 + $1.clipCount }
        let labelsWithAudio = labelRows.filter { $0.clipCount > 0 }.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill((isReady ? Color.green : Color.orange).opacity(0.22))
                        .frame(width: 58, height: 58)

                    Image(systemName: isReady ? "checkmark" : "exclamationmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(isReady ? Color.green.opacity(0.95) : Color.orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(isReady ? "Ready to train" : "Keep collecting audio")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("\(labelsWithAudio) of \(projectLabels.count) labels have audio · \(totalClips) clips")
                        .font(.caption.weight(.regular))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
            }

            Divider()
                .overlay(Color.white.opacity(0.08))

            VStack(spacing: 12) {
                ForEach(labelRows) { row in
                    readinessRow(row, maxClipCount: labelRows.map(\.clipCount).max() ?? 1)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    private func readinessRow(_ row: TrainingLabelReadinessRow, maxClipCount: Int) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(row.clipCount > 0 ? Color.green.opacity(0.95) : Color.orange)
                .frame(width: 12, height: 12)

            Text(row.label.name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 12)

            if row.clipCount > 0 {
                Capsule()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 96, height: 9)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color(red: 0.11, green: 0.53, blue: 0.98))
                            .frame(width: max(20, 96 * CGFloat(row.clipCount) / CGFloat(max(maxClipCount, 1))), height: 9)
                    }

                Text("\(row.clipCount)")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .frame(width: 24, alignment: .trailing)
            } else {
                Text("Needs audio")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.orange)
            }
        }
    }

    private func trainingActionButton(for project: Project, isReady: Bool) -> some View {
        Button {
            startTraining(for: project)
        } label: {
            HStack(spacing: 8) {
                if appContext.isStartingTraining {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }

                Text("Start training")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.29, green: 0.64, blue: 1.0),
                                Color(red: 0.09, green: 0.51, blue: 0.98)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .shadow(color: Color(red: 0.11, green: 0.53, blue: 0.98).opacity(0.35), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
        .disabled(!isReady || appContext.isStartingTraining)
        .opacity((!isReady || appContext.isStartingTraining) ? 0.55 : 1)
    }

    private var recordAudioButton: some View {
        Button {
            presentRecordingView()
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color(red: 1.0, green: 0.32, blue: 0.26))
                    .frame(width: 14, height: 14)
                    .shadow(color: Color.red.opacity(0.35), radius: 10)

                Text("Record audio")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.11, green: 0.53, blue: 0.98))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func latestVersionCard(for project: Project) -> some View {
        let latestVersion = appContext.latestKnownVersion(for: project.uid)
        let installed = latestVersion.map { version in
            appContext.activeProjectInstalledModels.contains(where: { $0.version == version })
        } ?? false

        return HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(latestVersion.map { "Latest version · v\($0)" } ?? "No trained versions yet")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(installed ? "Installed on this device" : "Manage versions and installs")
                    .font(.footnote.weight(.regular))
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            Spacer()

            Button("Manage", action: onViewModels)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(red: 0.11, green: 0.53, blue: 0.98))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
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
                                    presentRecordingView()
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
                        presentRecordingView()
                    } label: {
                        Text("Record audio")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(TintedActionButtonStyle(tint: Color(red: 0.91, green: 0.47, blue: 0.32)))
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
                        Image(systemName: symbolName(for: step))
                            .foregroundStyle(symbolColor(for: step))
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
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(TintedActionButtonStyle(tint: Color(red: 0.91, green: 0.47, blue: 0.32)))

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
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(TintedActionButtonStyle(tint: Color(red: 0.91, green: 0.47, blue: 0.32)))

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

    private func readinessLabelRows(for labels: [RecorderLabel]) -> [TrainingLabelReadinessRow] {
        labels
            .map { label in
                TrainingLabelReadinessRow(
                    label: label,
                    clipCount: labelRecordingCounts[label.uid] ?? 0
                )
            }
            .sorted { lhs, rhs in
                if lhs.clipCount == rhs.clipCount {
                    return lhs.label.name.localizedCaseInsensitiveCompare(rhs.label.name) == .orderedAscending
                }
                return lhs.clipCount > rhs.clipCount
            }
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

    private func presentRecordingView() {
        if showRecordingView {
            showRecordingView = false
            DispatchQueue.main.async {
                showRecordingView = true
            }
        } else {
            showRecordingView = true
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
                await MainActor.run {
                    labelRecordingCounts[selectedLabelUID, default: 0] += 1
                    showUploadSheet = false
                    self.pendingRecording = nil
                    AppHaptics.success()
                }
            } catch {
                await MainActor.run {
                    labelLoadingError = error.localizedDescription
                }
            }
            await MainActor.run {
                isUploading = false
            }
        }
    }

    private func installLatestVersion(version: String, projectUID: String) {
        isInstallingLatest = true
        installError = nil

        Task {
            do {
                try await appContext.installModel(projectUID: projectUID, version: version)
                await MainActor.run {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                        installSuccessMessage = "Model installed on this device"
                    }
                    installSuccessToken += 1
                }
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        installSuccessMessage = nil
                    }
                }
            } catch {
                await MainActor.run {
                    installError = error.localizedDescription
                }
            }
            await MainActor.run {
                isInstallingLatest = false
            }
        }
    }

    private func hasFreshCloudVersion(_ version: String, projectUID: String) -> Bool {
        !appContext.activeProjectInstalledModels.contains(where: { $0.version == version && $0.projectUID == projectUID })
    }

    private var trainingSteps: [String] {
        ["Uploading data", "Preprocessing", "Training model", "Packaging for device"]
    }

    private var currentTrainingStep: String {
        trainingSteps[displayedTrainingStepIndex]
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

    private func stageTrainingSequenceIfNeeded() {
        trainingStepTask?.cancel()

        guard let requestUID = appContext.trainingRequestUID else {
            displayedTrainingStepIndex = 0
            isHoldingCompletedTrainingState = false
            stagedTrainingRequestUID = nil
            failedTrainingHapticRequestUID = nil
            return
        }

        guard stagedTrainingRequestUID != requestUID else {
            return
        }

        stagedTrainingRequestUID = requestUID
        displayedTrainingStepIndex = 0
        isHoldingCompletedTrainingState = true

        trainingStepTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard stagedTrainingRequestUID == requestUID else { return }
                displayedTrainingStepIndex = 1
                AppHaptics.stepTick()
            }

            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard stagedTrainingRequestUID == requestUID else { return }
                displayedTrainingStepIndex = 2
                AppHaptics.stepTick()
            }
        }
    }

    private func reactToTrainingStatus() {
        if trainingDidFail {
            if failedTrainingHapticRequestUID != appContext.trainingRequestUID {
                failedTrainingHapticRequestUID = appContext.trainingRequestUID
                AppHaptics.failure()
            }
            isHoldingCompletedTrainingState = false
            return
        }

        guard let completedRequestUID = appContext.trainingRequestUID else {
            isHoldingCompletedTrainingState = false
            return
        }

        guard !appContext.isTrainingInProgress else {
            isHoldingCompletedTrainingState = true
            return
        }

        trainingStepTask?.cancel()
        trainingStepTask = Task {
            while !Task.isCancelled {
                let currentIndex = await MainActor.run { displayedTrainingStepIndex }
                if currentIndex >= 2 { break }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard stagedTrainingRequestUID == completedRequestUID else { return }
                displayedTrainingStepIndex = 3
                isHoldingCompletedTrainingState = true
                AppHaptics.stepTick()
            }

            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard stagedTrainingRequestUID == completedRequestUID else { return }
                isHoldingCompletedTrainingState = false
            }
        }
    }

    private func symbolName(for step: String) -> String {
        let index = trainingSteps.firstIndex(of: step) ?? 0
        if index < displayedTrainingStepIndex {
            return "checkmark.circle.fill"
        }
        if index == displayedTrainingStepIndex {
            return "record.circle.fill"
        }
        return "circle"
    }

    private func symbolColor(for step: String) -> Color {
        let index = trainingSteps.firstIndex(of: step) ?? 0
        if index < displayedTrainingStepIndex {
            return Color(red: 0.41, green: 0.80, blue: 1.0)
        }
        return Color(red: 0.91, green: 0.47, blue: 0.32)
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

private struct TrainingLabelReadinessRow: Identifiable {
    let label: RecorderLabel
    let clipCount: Int

    var id: String { label.uid }
}
