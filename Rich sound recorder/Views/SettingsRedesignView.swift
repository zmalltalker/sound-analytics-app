import SwiftUI

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

                NavigationLink {
                    DesignSystemShowcaseView()
                } label: {
                    settingsRow(title: "Design system", detail: "Preview")
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
