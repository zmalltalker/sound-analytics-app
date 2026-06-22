import AVFoundation
import SwiftUI

struct TrainWorkspaceView: View {
    @Environment(RedesignAppContext.self) private var appContext
    @Environment(TrainingSessionService.self) private var trainingSession

    let loginService: AuthenticationService
    @Binding var showProjectSwitcher: Bool
    let onViewModels: () -> Void
    let onOpenLabels: () -> Void

    private let recordingRepository: RecordingRepository
    private let projectRepository: ProjectRepository
    private let labelRepository: LabelRepository
    private let lastUsedLabelDefaultsKey = "train.lastUsedLabelByProject"

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
    @State private var isLoadingTrainingReadiness = false
    @State private var readinessError: String?
    @State private var didEmitFailureHaptic = false
    @State private var lastCompletedRequestUID: String?

    init(
        loginService: AuthenticationService,
        showProjectSwitcher: Binding<Bool>,
        onViewModels: @escaping () -> Void,
        onOpenLabels: @escaping () -> Void
    ) {
        self.loginService = loginService
        _showProjectSwitcher = showProjectSwitcher
        self.onViewModels = onViewModels
        self.onOpenLabels = onOpenLabels
        self.recordingRepository = RecordingRepository(loginService: loginService)
        self.projectRepository = ProjectRepository(loginService: loginService)
        self.labelRepository = LabelRepository(loginService: loginService)
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: RSRSpace.md) {
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
                            isReady: isReady,
                            isLoading: isLoadingTrainingReadiness
                        )

                        if trainingSession.activeProjectUID == activeProject.uid,
                           trainingSession.didFail {
                            trainingFailureCard(for: activeProject)
                        } else if trainingSession.activeProjectUID == activeProject.uid,
                                  let trainingState = trainingSession.displayState,
                                  !trainingSession.isSheetPresented {
                            RSRTrainingBar(state: trainingState) {
                                trainingSession.reopenSheet()
                            }
                        } else {
                            trainingActionButton(
                                for: activeProject,
                                isReady: isReady,
                                clipCount: readyLabels.reduce(0) { $0 + (labelRecordingCounts[$1.uid] ?? 0) }
                            )
                        }

                        recordAudioButton
                        latestVersionCard(for: activeProject)
                    } else {
                        RSRCard {
                            VStack(alignment: .leading, spacing: RSRSpace.sm) {
                                Text("No active project")
                                    .font(.rsrTitle)
                                    .tracking(RSRTracking.title)
                                    .foregroundStyle(RSR.labelPrimary)

                                Text("Create a project in Settings to start training.")
                                    .font(.rsrBody)
                                    .foregroundStyle(RSR.labelSecondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, RSRSpace.screen)
                .padding(.top, RSRSpace.sm)
                .padding(.bottom, max(104, geo.safeAreaInsets.bottom + 80))
            }
        }
        .background(RSR.canvas.ignoresSafeArea())
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
        .sheet(
            isPresented: Binding(
                get: { trainingSession.isSheetPresented },
                set: { trainingSession.isSheetPresented = $0 }
            )
        ) {
            if let trainingState = trainingSession.displayState {
                RSRTrainingSheet(
                    state: trainingState,
                    project: trainingSession.activeProjectName ?? appContext.activeProject?.name ?? "Project",
                    clipCount: trainingSession.clipCount,
                    onLeaveRunning: {
                        trainingSession.leaveRunning()
                    },
                    onCancel: {
                        trainingSession.cancelTraining()
                    },
                    onInstall: {
                        installCompletedTrainingIfAvailable()
                    },
                    onDone: {
                        trainingSession.doneViewingCompletion()
                    }
                )
                .presentationDetents([.height(620)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(38)
            }
        }
        .task(id: appContext.activeProject?.uid) {
            guard let activeProject = appContext.activeProject else { return }
            isLoadingTrainingReadiness = true
            labelRecordingCounts = [:]
            readinessError = nil

            defer {
                if appContext.activeProjectUID == activeProject.uid {
                    isLoadingTrainingReadiness = false
                }
            }

            await appContext.refreshAvailableModelVersions(for: activeProject.uid, force: true)
            await loadRecordingCounts(for: activeProject)
            if trainingSession.activeProjectUID == activeProject.uid, trainingSession.requestUID != nil {
                await trainingSession.refreshStatus()
            }
            if let latestVersion = appContext.latestKnownVersion(for: activeProject.uid) {
                _ = try? await appContext.modelSpecs(projectUID: activeProject.uid, version: latestVersion)
            }
        }
        .task(id: trainingSession.backendStatus ?? "") {
            reactToTrainingStatus()
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
                .font(.rsrLargeTitle)
                .tracking(RSRTracking.largeTitle)
                .foregroundStyle(RSR.labelPrimary)
        }
    }

    private func activeProjectCard(for project: Project) -> some View {
        RSRProjectSelector(name: project.name) {
            showProjectSwitcher = true
        }
    }

    private func readinessSummaryCard(
        for project: Project,
        projectLabels: [RecorderLabel],
        readyLabels: [RecorderLabel],
        isReady: Bool,
        isLoading: Bool
    ) -> some View {
        let labelRows = readinessLabelRows(for: projectLabels)
        let totalClips = labelRows.reduce(0) { $0 + $1.clipCount }
        let labelsWithAudio = labelRows.filter { $0.clipCount > 0 }.count

        return RSRCard(radius: RSRRadius.sheet) {
            VStack(alignment: .leading, spacing: RSRSpace.md) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(readinessHaloColor(isReady: isReady, isLoading: isLoading))
                            .frame(width: 58, height: 58)

                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .tint(RSR.labelPrimary)
                        } else {
                            Image(systemName: isReady ? "checkmark" : "exclamationmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(isReady ? RSR.success : RSR.warning)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(isLoading ? "Loading training status" : (isReady ? "Ready to train" : "Keep collecting audio"))
                            .font(.rsrTitle)
                            .tracking(RSRTracking.title)
                            .foregroundStyle(RSR.labelPrimary)

                        Text(
                            isLoading
                            ? "Checking labels and clip counts..."
                            : "\(labelsWithAudio) of \(projectLabels.count) labels have audio · \(totalClips) clips"
                        )
                        .font(.rsrSubhead)
                        .foregroundStyle(RSR.labelSecondary)
                    }
                }

                Divider()
                    .overlay(RSR.hairline)

                VStack(spacing: 0) {
                    if isLoading {
                        ForEach(Array(projectLabels.prefix(4))) { label in
                            readinessLoadingRow(labelName: label.name)
                        }
                    } else {
                        let maxClipCount = labelRows.map(\.clipCount).max() ?? 1
                        ForEach(labelRows) { row in
                            readinessRow(row, maxClipCount: maxClipCount)
                        }
                    }
                }
            }
        }
    }

    private func readinessRow(_ row: TrainingLabelReadinessRow, maxClipCount: Int) -> some View {
        RSRLabelRow(
            name: row.label.name,
            state: row.clipCount > 0
                ? .ready(clips: row.clipCount, fraction: Double(row.clipCount) / Double(max(maxClipCount, 1)))
                : .needsAudio
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func readinessLoadingRow(labelName: String) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(RSR.trackFill)
                .frame(width: 12, height: 12)

            Text(labelName)
                .font(.rsrBody.weight(.semibold))
                .foregroundStyle(RSR.labelSecondary)
                .lineLimit(1)

            Spacer(minLength: 12)

            Capsule()
                .fill(RSR.trackFill)
                .frame(width: 64, height: 6)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(RSR.labelTertiary)
                        .frame(width: 30, height: 6)
                }

            Text("...")
                .font(.rsrSubhead.weight(.semibold))
                .foregroundStyle(RSR.labelTertiary)
                .frame(width: 30, alignment: .trailing)
        }
        .frame(minHeight: 44)
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
    }

    private func trainingActionButton(for project: Project, isReady: Bool, clipCount: Int) -> some View {
        RSRPrimaryButton(title: trainingSession.isStarting ? "Starting training..." : "Start training") {
            startTraining(for: project, clipCount: clipCount)
        }
        .disabled(!isReady || trainingSession.isStarting)
        .opacity((!isReady || trainingSession.isStarting) ? 0.55 : 1)
    }

    private var recordAudioButton: some View {
        RSRSecondaryButton(title: "Record audio", showsRecordDot: true) {
            presentRecordingView()
        }
    }

    private func latestVersionCard(for project: Project) -> some View {
        let latestVersion = appContext.latestKnownVersion(for: project.uid)
        let installed = latestVersion.map { version in
            appContext.activeProjectInstalledModels.contains(where: { $0.version == version })
        } ?? false

        return RSRCard(radius: RSRRadius.control) {
            HStack(alignment: .center, spacing: RSRSpace.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(latestVersion.map { "Latest version · v\($0)" } ?? "No trained versions yet")
                        .font(.rsrBody.weight(.semibold))
                        .foregroundStyle(RSR.labelPrimary)

                    Text(installed ? "Installed on this device" : "Manage versions and installs")
                        .font(.rsrSubhead)
                        .foregroundStyle(RSR.labelSecondary)
                }

                Spacer()

                RSRTonalButton(title: "Manage", action: onViewModels)
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

                if let readinessError {
                    Text(readinessError)
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
                    startTraining(for: project, clipCount: labelRecordingCounts.values.reduce(0, +))
                } label: {
                    HStack(spacing: 8) {
                        if trainingSession.isStarting {
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
                .disabled(!isReady || trainingSession.isStarting)

                if !isReady, let blockingText {
                    Text(blockingText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func trainingFailureCard(for project: Project) -> some View {
        RSRCard {
            VStack(alignment: .leading, spacing: RSRSpace.md) {
                Text("Training failed")
                    .font(.rsrTitle)
                    .tracking(RSRTracking.title)
                    .foregroundStyle(RSR.labelPrimary)

                Text(trainingSession.backendStatus ?? "The latest training run did not finish successfully.")
                    .font(.rsrBody)
                    .foregroundStyle(RSR.labelSecondary)

                HStack(spacing: 12) {
                    RSRPrimaryButton(title: "Retry") {
                        startTraining(for: project, clipCount: labelRecordingCounts.values.reduce(0, +))
                    }
                    RSRTonalButton(title: "View in Models", action: onViewModels)
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
            readinessError = error.localizedDescription
        }
    }

    private func startTraining(for project: Project, clipCount: Int) {
        Task {
            await trainingSession.startTraining(
                projectUID: project.uid,
                projectName: project.name,
                clipCount: clipCount
            )
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
                let lastUsedLabelUID = lastUsedLabelUID(for: activeProject.uid)
                selectedLabelUID = filteredLabels.first(where: { $0.uid == lastUsedLabelUID })?.uid ?? filteredLabels.first?.uid
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
                    if let activeProjectUID = appContext.activeProject?.uid {
                        storeLastUsedLabelUID(selectedLabelUID, for: activeProjectUID)
                    }
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

    private func lastUsedLabelUID(for projectUID: String) -> String? {
        let persisted = UserDefaults.standard.dictionary(forKey: lastUsedLabelDefaultsKey) as? [String: String]
        return persisted?[projectUID]
    }

    private func storeLastUsedLabelUID(_ labelUID: String, for projectUID: String) {
        var persisted = UserDefaults.standard.dictionary(forKey: lastUsedLabelDefaultsKey) as? [String: String] ?? [:]
        persisted[projectUID] = labelUID
        UserDefaults.standard.set(persisted, forKey: lastUsedLabelDefaultsKey)
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

    private func installCompletedTrainingIfAvailable() {
        guard let projectUID = trainingSession.activeProjectUID else { return }

        Task {
            if appContext.latestKnownVersion(for: projectUID) == nil {
                await appContext.refreshAvailableModelVersions(for: projectUID, force: true)
            }

            guard let latestVersion = appContext.latestKnownVersion(for: projectUID) else { return }
            await MainActor.run {
                installLatestVersion(version: latestVersion, projectUID: projectUID)
            }
        }
    }

    private func hasFreshCloudVersion(_ version: String, projectUID: String) -> Bool {
        !appContext.activeProjectInstalledModels.contains(where: { $0.version == version && $0.projectUID == projectUID })
    }

    private func reactToTrainingStatus() {
        if trainingSession.didFail {
            if !didEmitFailureHaptic {
                didEmitFailureHaptic = true
                AppHaptics.failure()
            }
            return
        }

        didEmitFailureHaptic = false

        guard trainingSession.isCompleted,
              let requestUID = trainingSession.requestUID,
              lastCompletedRequestUID != requestUID else {
            return
        }

        lastCompletedRequestUID = requestUID
        AppHaptics.stepTick()

        if let activeProjectUID = trainingSession.activeProjectUID {
            Task {
                await appContext.refreshAvailableModelVersions(for: activeProjectUID, force: true)
            }
        }
    }

    private func readinessHaloColor(isReady: Bool, isLoading: Bool) -> Color {
        if isLoading {
            return RSR.trackFill
        }
        return (isReady ? RSR.success : RSR.warning).opacity(0.18)
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
