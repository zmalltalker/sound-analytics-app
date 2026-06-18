import SwiftUI

struct ModelsWorkspaceView: View {
    @Environment(RedesignAppContext.self) private var appContext

    @Binding var showProjectSwitcher: Bool

    @State private var isEditing = false
    @State private var isInstallingVersion: String?
    @State private var errorMessage: String?
    @State private var pendingRemoval: ProjectModelRowState?
    @State private var installSuccessMessage: String?
    @State private var installSuccessToken = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RSRSpace.lg) {
                if let activeProject = appContext.activeProject {
                    header(for: activeProject)
                    summaryCard(for: activeProject)
                    versionsCard(for: activeProject)

                    if isEditing {
                        Text("Removing deletes only the on-device copy and frees space. The trained version stays in the cloud and can be re-installed any time.")
                            .font(.rsrSubhead)
                            .foregroundStyle(RSR.labelSecondary)
                    }
                } else {
                    emptyProjectView
                }
            }
            .padding(.horizontal, RSRSpace.screen)
            .padding(.top, RSRSpace.card)
            .padding(.bottom, 120)
        }
        .background(RSR.canvas.ignoresSafeArea())
        .task(id: appContext.activeProjectUID) {
            guard let activeProjectUID = appContext.activeProjectUID else { return }
            await appContext.refreshAvailableModelVersions(for: activeProjectUID, force: true)
        }
        .alert("Remove downloaded model?", isPresented: removalConfirmationBinding) {
            Button("Cancel", role: .cancel) {
                pendingRemoval = nil
            }
            Button("Remove", role: .destructive) {
                confirmRemoval()
            }
        } message: {
            Text(removalMessage)
        }
        .overlay(alignment: .bottom) {
            if let installSuccessMessage {
                SuccessToast(title: installSuccessMessage)
                    .padding(.horizontal, RSRSpace.screen)
                    .padding(.bottom, 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: installSuccessToken) { _, newValue in
            guard newValue > 0 else { return }
            AppHaptics.success()
        }
    }

    private func header(for activeProject: Project) -> some View {
        HStack(alignment: .center) {
            Text("Models")
                .font(.rsrLargeTitle)
                .tracking(RSRTracking.largeTitle)
                .foregroundStyle(RSR.labelPrimary)

            Spacer(minLength: 16)

            RSRProjectChip(name: activeProject.name) {
                showProjectSwitcher = true
            }
        }
    }

    private func summaryCard(for project: Project) -> some View {
        RSRCard {
            HStack(alignment: .top, spacing: RSRSpace.md) {
                VStack(alignment: .leading, spacing: RSRSpace.xs) {
                    Text("On device")
                        .font(.rsrTitle)
                        .tracking(RSRTracking.title)
                        .foregroundStyle(RSR.labelPrimary)

                    Text("\(appContext.activeProjectInstalledModels.count) versions · \(formattedStorage(appContext.activeProjectInstalledModels.reduce(0) { $0 + $1.sizeBytes }))")
                        .font(.rsrMeta)
                        .foregroundStyle(RSR.labelSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: RSRSpace.xs) {
                    Text("Default")
                        .font(.rsrCaption)
                        .tracking(RSRTracking.eyebrow)
                        .foregroundStyle(RSR.labelSecondary)

                    Text(modelSubtitle(for: project.uid))
                        .font(.rsrBody.weight(.semibold))
                        .foregroundStyle(RSR.labelPrimary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    private func versionsCard(for project: Project) -> some View {
        RSRCard {
            VStack(alignment: .leading, spacing: RSRSpace.md) {
                HStack {
                    Text("Versions")
                        .font(.rsrTitle)
                        .tracking(RSRTracking.title)
                        .foregroundStyle(RSR.labelPrimary)

                    Spacer()

                    RSRTonalButton(title: isEditing ? "Done" : "Edit") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditing.toggle()
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.rsrSubhead)
                        .foregroundStyle(RSR.danger)
                }

                let rows = modelRows(for: project.uid)
                if rows.isEmpty {
                    Text("No model versions found for this project yet.")
                        .font(.rsrSubhead)
                        .foregroundStyle(RSR.labelSecondary)
                } else {
                    VStack(spacing: RSRSpace.sm) {
                        ForEach(rows) { row in
                            modelRow(row, projectUID: project.uid)
                        }
                    }
                }
            }
        }
    }

    private var emptyProjectView: some View {
        RSRCard {
            Text("Create a project in Settings to manage model versions.")
                .font(.rsrSubhead)
                .foregroundStyle(RSR.labelSecondary)
        }
    }

    private func modelSubtitle(for projectUID: String) -> String {
        if let defaultModel = appContext.defaultInstalledModel(for: projectUID) {
            return "v\(defaultModel.version)"
        }
        return "None"
    }

    private func modelRows(for projectUID: String) -> [ProjectModelRowState] {
        let installed = appContext.installedModels.filter { $0.projectUID == projectUID }
        let installedByVersion = Dictionary(uniqueKeysWithValues: installed.map { ($0.version, $0) })
        let cloudVersions = Set(appContext.availableModelVersionsByProject[projectUID] ?? [])
        let allVersions = Set(installedByVersion.keys).union(cloudVersions)

        return allVersions
            .sorted(by: { compareModelVersion($0, $1) == .orderedDescending })
            .map { version in
                ProjectModelRowState(
                    version: version,
                    installedModel: installedByVersion[version],
                    isDefault: appContext.defaultModelVersionsByProject[projectUID] == version
                )
            }
    }

    private func modelRow(_ row: ProjectModelRowState, projectUID: String) -> some View {
        HStack(alignment: .center, spacing: RSRSpace.md) {
            VStack(alignment: .leading, spacing: RSRSpace.sm) {
                HStack(spacing: RSRSpace.sm) {
                    Text("v\(row.version)")
                        .font(.rsrBody.weight(.semibold))
                        .foregroundStyle(RSR.labelPrimary)

                    modelBadge(row.installedModel == nil ? "Cloud" : "On device", tint: row.installedModel == nil ? RSR.labelSecondary : RSR.accent)

                    if row.isDefault {
                        modelBadge("Default", tint: RSR.accent)
                    }
                }

                Text(modelDetailText(row))
                    .font(.rsrMeta)
                    .foregroundStyle(RSR.labelSecondary)
            }

            Spacer(minLength: 12)

            trailingAction(for: row, projectUID: projectUID)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .rsrGlass(.regular, radius: RSRRadius.control, fill: RSR.surfaceGlass, elevation: .card)
        .opacity(isEditing && row.installedModel == nil ? 0.55 : 1)
    }

    @ViewBuilder
    private func trailingAction(for row: ProjectModelRowState, projectUID: String) -> some View {
        if isEditing, row.installedModel != nil {
            Button(role: .destructive) {
                requestRemoval(for: row, projectUID: projectUID)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(RSR.danger)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(RSR.danger.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
        } else if row.installedModel == nil {
            Button {
                install(version: row.version, for: projectUID)
            } label: {
                HStack(spacing: 8) {
                    if isInstallingVersion == row.version {
                        ProgressView()
                            .tint(RSR.accent)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }

                    Text(isInstallingVersion == row.version ? "Installing" : "Install")
                        .font(.rsrSubhead.weight(.semibold))
                }
                .foregroundStyle(RSR.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(RSR.accentTint)
                .clipShape(RoundedRectangle(cornerRadius: RSRRadius.chip, style: .continuous))
            }
            .buttonStyle(.plain)
        } else {
            Button {
                if let version = row.installedModel?.version {
                    appContext.setDefaultModelVersion(version, for: projectUID)
                    AppHaptics.stepTick()
                }
            } label: {
                Text(row.isDefault ? "Selected" : "Set default")
                    .font(.rsrSubhead.weight(.semibold))
                    .foregroundStyle(row.isDefault ? RSR.labelPrimary : RSR.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(row.isDefault ? RSR.surfaceGlassStrong : RSR.accentTint)
                    .clipShape(RoundedRectangle(cornerRadius: RSRRadius.chip, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func install(version: String, for projectUID: String) {
        isInstallingVersion = version
        errorMessage = nil

        Task {
            do {
                try await appContext.installModel(projectUID: projectUID, version: version)
                await MainActor.run {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                        installSuccessMessage = "Version \(version) installed on this device"
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
                    errorMessage = error.localizedDescription
                }
            }
            await MainActor.run {
                isInstallingVersion = nil
            }
        }
    }

    private func modelDetailText(_ row: ProjectModelRowState) -> String {
        if let installedModel = row.installedModel {
            let labelCount = installedModel.labelCount
            let modifiedText = installedModel.modifiedAt?.formatted(date: .abbreviated, time: .omitted) ?? "On device"
            return "\(modifiedText) · \(labelCount) labels · \(formattedStorage(installedModel.sizeBytes))"
        }
        return isEditing ? "Cloud only · not on device" : "Available in cloud"
    }

    private func modelBadge(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.rsrCaption)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
    }

    private func requestRemoval(for row: ProjectModelRowState, projectUID: String) {
        let installedCount = appContext.activeProjectInstalledModels.count
        if row.isDefault || installedCount == 1 {
            pendingRemoval = row
            return
        }

        do {
            try appContext.removeInstalledModel(projectUID: projectUID, version: row.version)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func confirmRemoval() {
        guard let pendingRemoval, let projectUID = appContext.activeProjectUID else { return }
        do {
            try appContext.removeInstalledModel(projectUID: projectUID, version: pendingRemoval.version)
        } catch {
            errorMessage = error.localizedDescription
        }
        self.pendingRemoval = nil
    }

    private var removalConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingRemoval != nil },
            set: { isPresented in
                if !isPresented {
                    pendingRemoval = nil
                }
            }
        )
    }

    private var removalMessage: String {
        guard let pendingRemoval else { return "" }
        if pendingRemoval.isDefault {
            return "This clears the project's default model on this device. You can install or choose another version later."
        }
        return "This removes the last on-device copy for the project. The trained cloud version stays available to re-install."
    }
}

private struct ProjectModelRowState: Identifiable {
    let version: String
    let installedModel: InstalledProjectModel?
    let isDefault: Bool

    var id: String { version }
}
