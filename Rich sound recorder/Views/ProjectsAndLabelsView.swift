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
