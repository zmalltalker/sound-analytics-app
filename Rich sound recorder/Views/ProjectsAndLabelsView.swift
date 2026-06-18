import SwiftUI

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
        ScrollView {
            VStack(alignment: .leading, spacing: RSRSpace.lg) {
                pageHeader(
                    title: "Projects",
                    subtitle: "Manage project groups and assigned labels."
                )

                stateSection
            }
            .padding(.horizontal, RSRSpace.screen)
            .padding(.top, RSRSpace.card)
            .padding(.bottom, 120)
        }
        .background(RSR.canvas.ignoresSafeArea())
        .navigationTitle("Projects")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewProjectSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(RSR.accent)
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
        .refreshable {
            fetchProjects()
        }
        .task {
            repository = ProjectRepository(loginService: loginService)
            labelRepository = LabelRepository(loginService: loginService)
            fetchProjects()
        }
    }

    @ViewBuilder
    private var stateSection: some View {
        if isLoading {
            loadingCard("Loading projects...")
        } else if let error = errorMessage {
            messageCard(
                title: "Couldn’t load projects",
                subtitle: error,
                systemImage: "exclamationmark.triangle.fill",
                tint: RSR.warning
            ) {
                Button("Retry") { fetchProjects() }
                    .font(.rsrSubhead.weight(.semibold))
                    .foregroundStyle(RSR.accent)
            }
        } else if projects.isEmpty {
            messageCard(
                title: "No projects yet",
                subtitle: "Create a project to organize labels and training data.",
                systemImage: "folder.badge.plus",
                tint: RSR.accent
            ) {
                RSRPrimaryButton(title: "New project") {
                    showNewProjectSheet = true
                }
            }
        } else {
            VStack(spacing: RSRSpace.sm) {
                ForEach(projects) { project in
                    ProjectListRow(
                        project: project,
                        projectRepository: repository,
                        labelRepository: labelRepository,
                        onProjectUpdated: replaceProject,
                        onProjectDeleted: removeProject
                    )
                }
            }
        }
    }

    private func removeProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
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
    let onProjectDeleted: (Project) -> Void

    var body: some View {
        if let projectRepository, let labelRepository {
            NavigationLink {
                ProjectDetailView(
                    project: project,
                    projectRepository: projectRepository,
                    labelRepository: labelRepository,
                    onProjectUpdated: onProjectUpdated,
                    onProjectDeleted: onProjectDeleted
                )
            } label: {
                ProjectRow(project: project)
            }
            .buttonStyle(.plain)
        } else {
            ProjectRow(project: project)
        }
    }
}

struct ProjectRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: 14) {
            RSRGlyphTile(size: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.rsrHeadline)
                    .foregroundStyle(RSR.labelPrimary)
                    .lineLimit(1)

                if !project.description.isEmpty {
                    Text(project.description)
                        .font(.rsrSubhead)
                        .foregroundStyle(RSR.labelSecondary)
                        .lineLimit(2)
                }

                Text("\(project.labelUIDs.count) label\(project.labelUIDs.count == 1 ? "" : "s") assigned")
                    .font(.rsrSubhead.weight(.semibold))
                    .foregroundStyle(RSR.accent)
            }

            Spacer(minLength: 10)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RSR.labelTertiary)
        }
        .padding(RSRSpace.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rsrGlass(.regular, radius: RSRRadius.card, elevation: .card)
    }
}

struct ProjectDetailView: View {
    let projectRepository: ProjectRepository
    let labelRepository: LabelRepository
    let onProjectUpdated: (Project) -> Void
    let onProjectDeleted: (Project) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var project: Project
    @State private var availableLabels: [RecorderLabel] = []
    @State private var isLoadingLabels = true
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    init(
        project: Project,
        projectRepository: ProjectRepository,
        labelRepository: LabelRepository,
        onProjectUpdated: @escaping (Project) -> Void,
        onProjectDeleted: @escaping (Project) -> Void
    ) {
        self.projectRepository = projectRepository
        self.labelRepository = labelRepository
        self.onProjectUpdated = onProjectUpdated
        self.onProjectDeleted = onProjectDeleted
        _project = State(initialValue: project)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RSRSpace.lg) {
                pageHeader(
                    title: project.name,
                    subtitle: project.description.isEmpty ? "Active project configuration." : project.description
                )

                projectSummaryCard

                if let successMessage {
                    bannerCard(message: successMessage, tint: RSR.success)
                }

                if let errorMessage {
                    bannerCard(message: errorMessage, tint: RSR.warning)
                }

                labelsSection
            }
            .padding(.horizontal, RSRSpace.screen)
            .padding(.top, RSRSpace.card)
            .padding(.bottom, 120)
        }
        .background(RSR.canvas.ignoresSafeArea())
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    deleteProject()
                } label: {
                    if isDeleting {
                        ProgressView()
                            .tint(RSR.danger)
                    } else {
                        Image(systemName: "trash")
                            .foregroundStyle(RSR.danger)
                    }
                }
                .disabled(isDeleting)
            }
        }
        .task {
            await loadLabels()
        }
        .refreshable {
            await loadLabels()
        }
    }

    private var projectSummaryCard: some View {
        RSRCard(radius: RSRRadius.card) {
            VStack(alignment: .leading, spacing: RSRSpace.md) {
                Text("Project")
                    .font(.rsrCaption)
                    .tracking(RSRTracking.eyebrow)
                    .foregroundStyle(RSR.labelSecondary)
                    .textCase(.uppercase)

                detailRow(title: "Name", value: project.name)
                detailRow(title: "Description", value: project.description.isEmpty ? "No description" : project.description)
                detailRow(title: "Assigned labels", value: "\(project.labelUIDs.count)")
            }
        }
    }

    private var labelsSection: some View {
        VStack(alignment: .leading, spacing: RSRSpace.md) {
            sectionTitle("Labels")

            if isLoadingLabels {
                loadingCard("Loading labels...")
            } else if availableLabels.isEmpty {
                messageCard(
                    title: "No labels available",
                    subtitle: "Create labels from Settings before assigning them to a project.",
                    systemImage: "tag.slash",
                    tint: RSR.labelSecondary
                )
            } else {
                VStack(spacing: RSRSpace.sm) {
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

    private func deleteProject() {
        isDeleting = true
        errorMessage = nil

        Task {
            do {
                try await projectRepository.delete(project)
                onProjectDeleted(project)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isDeleting = false
            }
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
        HStack(spacing: 14) {
            Circle()
                .fill(isAssigned ? RSR.success : RSR.labelTertiary)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(label.name)
                    .font(.rsrBody.weight(.semibold))
                    .foregroundStyle(RSR.labelPrimary)

                if !label.description.isEmpty {
                    Text(label.description)
                        .font(.rsrSubhead)
                        .foregroundStyle(RSR.labelSecondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 10)

            if isAssigned {
                Text("Assigned")
                    .font(.rsrSubhead.weight(.semibold))
                    .foregroundStyle(RSR.success)
            } else if isSaving {
                ProgressView()
                    .tint(RSR.accent)
            } else {
                Button("Assign", action: onAssign)
                    .font(.rsrSubhead.weight(.semibold))
                    .foregroundStyle(RSR.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RSR.accentTint)
                    .clipShape(RoundedRectangle(cornerRadius: RSRRadius.chip, style: .continuous))
            }
        }
        .padding(RSRSpace.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rsrGlass(.regular, radius: RSRRadius.control, elevation: .resting)
    }
}

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
            ScrollView {
                VStack(alignment: .leading, spacing: RSRSpace.lg) {
                    pageHeader(
                        title: "New project",
                        subtitle: "Create a container for labels, recordings, and training."
                    )

                    RSRCard(radius: RSRRadius.card) {
                        VStack(alignment: .leading, spacing: RSRSpace.md) {
                            settingsField(title: "Name", text: $name, prompt: "Compressor line A")
                            settingsField(title: "Description", text: $description, prompt: "Optional")
                        }
                    }

                    if let errorMessage {
                        bannerCard(message: errorMessage, tint: RSR.warning)
                    }
                }
                .padding(.horizontal, RSRSpace.screen)
                .padding(.top, RSRSpace.card)
                .padding(.bottom, 40)
            }
            .background(RSR.canvas.ignoresSafeArea())
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(RSR.accent)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                            .tint(RSR.accent)
                    } else {
                        Button("Create") { createProject() }
                            .foregroundStyle(RSR.accent)
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
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

struct LabelsTab: View {
    let loginService: AuthenticationService
    @Binding var showProfileSheet: Bool
    let wrapInNavigation: Bool

    @State private var repository: LabelRepository?
    @State private var clipRepository: ClipRepository?
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
        ScrollView {
            VStack(alignment: .leading, spacing: RSRSpace.lg) {
                pageHeader(
                    title: "Labels",
                    subtitle: "Create and review the training classes used across projects."
                )

                labelsSection
            }
            .padding(.horizontal, RSRSpace.screen)
            .padding(.top, RSRSpace.card)
            .padding(.bottom, 120)
        }
        .background(RSR.canvas.ignoresSafeArea())
        .navigationTitle("Labels")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewLabelSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(RSR.accent)
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
        .refreshable {
            fetchLabels()
        }
        .task {
            repository = LabelRepository(loginService: loginService)
            clipRepository = ClipRepository(loginService: loginService)
            fetchLabels()
        }
    }

    @ViewBuilder
    private var labelsSection: some View {
        if isLoading {
            loadingCard("Loading labels...")
        } else if let error = errorMessage {
            messageCard(
                title: "Couldn’t load labels",
                subtitle: error,
                systemImage: "exclamationmark.triangle.fill",
                tint: RSR.warning
            ) {
                Button("Retry") { fetchLabels() }
                    .font(.rsrSubhead.weight(.semibold))
                    .foregroundStyle(RSR.accent)
            }
        } else if labels.isEmpty {
            messageCard(
                title: "No labels yet",
                subtitle: "Create a label to start tagging recordings and training models.",
                systemImage: "tag.badge.plus",
                tint: RSR.accent
            ) {
                RSRPrimaryButton(title: "New label") {
                    showNewLabelSheet = true
                }
            }
        } else {
            VStack(spacing: RSRSpace.sm) {
                ForEach(labels) { label in
                    if let clipRepository {
                        NavigationLink {
                            LabelDetailView(
                                labelUID: label.uid,
                                labelName: label.name,
                                clipRepository: clipRepository
                            )
                        } label: {
                            LabelRow(label: label)
                        }
                        .buttonStyle(.plain)
                    } else {
                        LabelRow(label: label)
                    }
                }
            }
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

struct LabelRow: View {
    let label: RecorderLabel

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(RSR.accentTint)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(RSR.accent)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(label.name)
                    .font(.rsrHeadline)
                    .foregroundStyle(RSR.labelPrimary)
                    .lineLimit(1)

                if !label.description.isEmpty {
                    Text(label.description)
                        .font(.rsrSubhead)
                        .foregroundStyle(RSR.labelSecondary)
                        .lineLimit(2)
                } else {
                    Text(durationSummary)
                        .font(.rsrSubhead)
                        .foregroundStyle(RSR.labelSecondary)
                }
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 4) {
                if label.duration > 0 {
                    Text(durationSummary)
                        .font(.rsrMeta)
                        .foregroundStyle(RSR.labelSecondary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RSR.labelTertiary)
            }
        }
        .padding(RSRSpace.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rsrGlass(.regular, radius: RSRRadius.card, elevation: .card)
    }

    private var durationSummary: String {
        guard label.duration > 0 else { return "Default duration" }
        return String(format: "%.1f sec window", label.duration)
    }
}

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
            ScrollView {
                VStack(alignment: .leading, spacing: RSRSpace.lg) {
                    pageHeader(
                        title: "New label",
                        subtitle: "Define a training class and its preferred clip duration."
                    )

                    RSRCard(radius: RSRRadius.card) {
                        VStack(alignment: .leading, spacing: RSRSpace.md) {
                            settingsField(title: "Name", text: $name, prompt: "Cavitation")
                            settingsField(title: "Description", text: $description, prompt: "Optional")
                            settingsField(title: "Duration (seconds)", text: $durationSeconds, prompt: "0")
                                .keyboardType(.decimalPad)
                        }
                    }

                    if let errorMessage {
                        bannerCard(message: errorMessage, tint: RSR.warning)
                    }
                }
                .padding(.horizontal, RSRSpace.screen)
                .padding(.top, RSRSpace.card)
                .padding(.bottom, 40)
            }
            .background(RSR.canvas.ignoresSafeArea())
            .navigationTitle("New Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(RSR.accent)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                            .tint(RSR.accent)
                    } else {
                        Button("Create") { createLabel() }
                            .foregroundStyle(RSR.accent)
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func createLabel() {
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let duration = Double(durationSeconds.replacingOccurrences(of: ",", with: ".")) ?? 0
                try await repository.create(
                    name: name.trimmingCharacters(in: .whitespaces),
                    description: description.trimmingCharacters(in: .whitespaces),
                    durationSeconds: duration
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

private func pageHeader(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: RSRSpace.xs) {
        Text(title)
            .font(.rsrLargeTitle)
            .tracking(RSRTracking.largeTitle)
            .foregroundStyle(RSR.labelPrimary)

        Text(subtitle)
            .font(.rsrSubhead)
            .foregroundStyle(RSR.labelSecondary)
    }
}

private func sectionTitle(_ title: String) -> some View {
    Text(title)
        .font(.rsrCaption)
        .tracking(RSRTracking.eyebrow)
        .foregroundStyle(RSR.labelSecondary)
        .textCase(.uppercase)
}

private func detailRow(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title)
            .font(.rsrCaption)
            .tracking(RSRTracking.eyebrow)
            .foregroundStyle(RSR.labelSecondary)
            .textCase(.uppercase)

        Text(value)
            .font(.rsrBody.weight(.semibold))
            .foregroundStyle(RSR.labelPrimary)
    }
}

private func loadingCard(_ title: String) -> some View {
    RSRCard(radius: RSRRadius.card) {
        HStack(spacing: RSRSpace.md) {
            ProgressView()
                .tint(RSR.accent)
            Text(title)
                .font(.rsrBody.weight(.semibold))
                .foregroundStyle(RSR.labelPrimary)
        }
    }
}

private func messageCard<Accessory: View>(
    title: String,
    subtitle: String,
    systemImage: String,
    tint: Color,
    @ViewBuilder accessory: () -> Accessory
) -> some View {
    RSRCard(radius: RSRRadius.card) {
        VStack(alignment: .leading, spacing: RSRSpace.md) {
            HStack(spacing: 14) {
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(tint)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.rsrHeadline)
                        .foregroundStyle(RSR.labelPrimary)

                    Text(subtitle)
                        .font(.rsrSubhead)
                        .foregroundStyle(RSR.labelSecondary)
                }
            }

            accessory()
        }
    }
}

private func messageCard(
    title: String,
    subtitle: String,
    systemImage: String,
    tint: Color
) -> some View {
    messageCard(
        title: title,
        subtitle: subtitle,
        systemImage: systemImage,
        tint: tint
    ) {
        EmptyView()
    }
}

private func bannerCard(message: String, tint: Color) -> some View {
    RSRCard(radius: RSRRadius.control) {
        Text(message)
            .font(.rsrSubhead.weight(.semibold))
            .foregroundStyle(tint)
    }
}

private func settingsField(title: String, text: Binding<String>, prompt: String) -> some View {
    VStack(alignment: .leading, spacing: RSRSpace.sm) {
        Text(title)
            .font(.rsrCaption)
            .tracking(RSRTracking.eyebrow)
            .foregroundStyle(RSR.labelSecondary)
            .textCase(.uppercase)

        TextField(prompt, text: text)
            .font(.rsrBody)
            .foregroundStyle(RSR.labelPrimary)
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .rsrGlass(.thin, radius: RSRRadius.control, elevation: .resting)
    }
}
