import SwiftUI

struct HomeLaunchView: View {
    @Environment(RedesignAppContext.self) private var appContext

    @Binding var selectedSection: AppSection
    @Binding var showingHome: Bool
    @Binding var showProjectSwitcher: Bool
    let onOpenProjects: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("WORKING IN")
                        .font(.caption.monospaced())
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .tracking(1.6)

                    if let activeProject = appContext.activeProject {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(activeProject.name)
                                    .font(.system(size: 38, weight: .bold))
                                    .foregroundStyle(.primary)
                                Text("Active project")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Switch") {
                                showProjectSwitcher = true
                            }
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial.opacity(0.9))
                            )
                        }
                    } else {
                        Button {
                            onOpenProjects()
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Create your first project")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.primary)
                                Text("Go to Settings to set up projects and labels.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color.white.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                taskRow(
                    title: "Train",
                    subtitle: "Record & improve a model",
                    systemImage: "waveform.path.badge.plus",
                    accent: Color(red: 0.91, green: 0.47, blue: 0.32)
                ) {
                    selectedSection = .train
                    showingHome = false
                }

                taskRow(
                    title: "Detect",
                    subtitle: "Listen & label live sound",
                    systemImage: "dot.scope",
                    accent: Color(red: 0.41, green: 0.80, blue: 1.0)
                ) {
                    selectedSection = .detect
                    showingHome = false
                }

                Button {
                    selectedSection = .models
                    showingHome = false
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.stack.3d.up")
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        Text("\(appContext.totalInstalledModelCount) models on device · \(formattedStorage(appContext.totalInstalledStorageBytes))")
                            .font(.subheadline.monospaced())
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("Manage")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
    }

    private func taskRow(title: String, subtitle: String, systemImage: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(accent.opacity(0.14))
                        .frame(width: 64, height: 64)
                    Image(systemName: systemImage)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(accent)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(accent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SettingsWorkspaceView: View {
    @Environment(RedesignAppContext.self) private var appContext

    let loginService: AuthenticationService
    @Binding var showProfileSheet: Bool
    @Binding var destination: SetupDestination?
    @StateObject private var recordingSettingsStore = RecordingSettingsStore.shared

    var body: some View {
        List {
            Section("Account") {
                Button {
                    showProfileSheet = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(loginService.username ?? "Account")
                                .foregroundStyle(.primary)
                            Text("Signed in via Azure")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .listRowBackground(Color.white.opacity(0.06))

            Section("Setup") {
                NavigationLink {
                    ProjectsTab(
                        loginService: loginService,
                        showProfileSheet: $showProfileSheet,
                        wrapInNavigation: false
                    )
                } label: {
                    settingsRow(title: "Projects", count: "\(appContext.projects.count)")
                }

                NavigationLink {
                    LabelsTab(
                        loginService: loginService,
                        showProfileSheet: $showProfileSheet,
                        wrapInNavigation: false
                    )
                } label: {
                    settingsRow(title: "Labels", count: "\(appContext.labels.count)")
                }
            }
            .listRowBackground(Color.white.opacity(0.06))

            Section("App") {
                NavigationLink {
                    RecordingSettingsScreen()
                } label: {
                    settingsRow(title: "Recording settings", detail: recordingSettingsStore.settings.summaryText)
                }
                settingsRow(title: "Notifications", detail: "Not in scope")
            }
            .listRowBackground(Color.white.opacity(0.06))
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func settingsRow(title: String, count: String? = nil, detail: String? = nil) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)

            Spacer()

            if let count {
                Text(count)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
