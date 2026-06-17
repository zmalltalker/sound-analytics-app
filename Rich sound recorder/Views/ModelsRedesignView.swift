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
            VStack(alignment: .leading, spacing: 20) {
                if let activeProject = appContext.activeProject {
                    InstrumentCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Versions")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Button(isEditing ? "Done" : "Edit") {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isEditing.toggle()
                                    }
                                }
                                .foregroundStyle(.secondary)
                            }

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }

                            if modelRows(for: activeProject.uid).isEmpty {
                                Text("No model versions found for this project yet.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(modelRows(for: activeProject.uid)) { row in
                                    modelRow(row, projectUID: activeProject.uid)
                                }
                            }
                        }
                    }

                    if isEditing {
                        Text("Removing deletes only the on-device copy and frees space. The trained version stays in the cloud — re-install any time.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }

                    Text("On device: \(appContext.activeProjectInstalledModels.count) versions · \(formattedStorage(appContext.activeProjectInstalledModels.reduce(0) { $0 + $1.sizeBytes }))")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                } else {
                    emptyProjectView
                }
            }
            .padding(20)
            .padding(.top, 8)
            .padding(.bottom, 80)
        }
        .background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            if let activeProject = appContext.activeProject {
                ContextHeader(
                    title: activeProject.name,
                    subtitle: modelSubtitle(for: activeProject.uid),
                    onSwitch: { showProjectSwitcher = true }
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .background(Color.clear)
            }
        }
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

    private var emptyProjectView: some View {
        InstrumentCard {
            Text("Create a project in Settings to manage model versions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func modelSubtitle(for projectUID: String) -> String {
        if let defaultModel = appContext.defaultInstalledModel(for: projectUID) {
            return "Default v\(defaultModel.version) · on device"
        }
        return "No default model selected"
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

    @ViewBuilder
    private func modelRow(_ row: ProjectModelRowState, projectUID: String) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("v\(row.version)")
                        .font(.headline.monospaced())
                        .foregroundStyle(.primary)

                    badge(row.installedModel == nil ? "CLOUD" : "ON DEVICE")

                    if row.isDefault {
                        badge("DEFAULT", tint: Color(red: 0.41, green: 0.80, blue: 1.0))
                    } else if isEditing, row.installedModel == nil {
                        badge("NOT ON DEVICE")
                    }
                }

                Text(modelDetailText(row))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isEditing, row.installedModel != nil {
                Button(role: .destructive) {
                    requestRemoval(for: row, projectUID: projectUID)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            } else if row.installedModel == nil {
                Button {
                    install(version: row.version, for: projectUID)
                } label: {
                    if isInstallingVersion == row.version {
                        ProgressView()
                            .tint(Color(red: 0.91, green: 0.47, blue: 0.32))
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color(red: 0.91, green: 0.47, blue: 0.32))
                    }
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    if let version = row.installedModel?.version {
                        appContext.setDefaultModelVersion(version, for: projectUID)
                    }
                } label: {
                    Text(row.isDefault ? "★" : "☆")
                        .font(.title3)
                        .foregroundStyle(Color(red: 0.41, green: 0.80, blue: 1.0))
                }
                .buttonStyle(.plain)
                .disabled(row.installedModel == nil)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.05))
        )
        .opacity(isEditing && row.installedModel == nil ? 0.55 : 1)
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

    private func badge(_ title: String, tint: Color = .secondary) -> some View {
        Text(title)
            .font(.caption2.monospaced())
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
