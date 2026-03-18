//
//  MainView.swift
//  Rich sound recorder
//
//  Created by Marius Mathiesen on 17/03/2026.
//

import SwiftUI

struct MainView: View {
    let loginService: AuthenticationService
    @State private var showProfileSheet = false

    var body: some View {
        TabView {
            ProjectsTab(loginService: loginService, showProfileSheet: $showProfileSheet)
                .tabItem {
                    Label("Projects", systemImage: "folder.fill")
                }

            LabelsTab(showProfileSheet: $showProfileSheet)
                .tabItem {
                    Label("Labels", systemImage: "tag.fill")
                }

            RecordingsTab(showProfileSheet: $showProfileSheet)
                .tabItem {
                    Label("Recordings", systemImage: "waveform")
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

    @State private var repository: ProjectRepository?
    @State private var projects: [Project] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showNewProjectSheet = false

    var body: some View {
        NavigationStack {
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
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(project.name)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                    if !project.description.isEmpty {
                                        Text(project.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
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
                fetchProjects()
            }
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
    @Binding var showProfileSheet: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.cyan.opacity(0.5))

                    Text("Labels")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Coming soon")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
            }
        }
    }
}

// MARK: - Recordings Tab

struct RecordingsTab: View {
    @Binding var showProfileSheet: Bool
    @State private var lastRecordingURL: URL?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.cyan)

                        Text("Audio Recordings")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("Record and manage your audio files")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    NavigationLink {
                        RecordingView { url in
                            lastRecordingURL = url
                        }
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
                        .padding(.horizontal, 40)
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
            }
            .navigationTitle("Recordings")
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
