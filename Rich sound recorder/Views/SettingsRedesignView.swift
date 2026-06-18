import SwiftUI

struct SettingsWorkspaceView: View {
    @Environment(RedesignAppContext.self) private var appContext

    let loginService: AuthenticationService
    @Binding var showProfileSheet: Bool
    @Binding var destination: SetupDestination?
    @StateObject private var recordingSettingsStore = RecordingSettingsStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RSRSpace.lg) {
                headerSection
                accountSection
                setupSection
                appSection
            }
            .padding(.horizontal, RSRSpace.screen)
            .padding(.top, RSRSpace.card)
            .padding(.bottom, 120)
        }
        .background(RSR.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: RSRSpace.xs) {
            Text("Settings")
                .font(.rsrLargeTitle)
                .tracking(RSRTracking.largeTitle)
                .foregroundStyle(RSR.labelPrimary)

            Text("Account, setup, and recording preferences.")
                .font(.rsrSubhead)
                .foregroundStyle(RSR.labelSecondary)
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: RSRSpace.md) {
            sectionTitle("Account")

            Button {
                showProfileSheet = true
            } label: {
                HStack(spacing: 14) {
                    Circle()
                        .fill(RSR.accentTint)
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(RSR.accent)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(loginService.username ?? "Account")
                            .font(.rsrBody.weight(.semibold))
                            .foregroundStyle(RSR.labelPrimary)

                        Text("Signed in via Azure")
                            .font(.rsrSubhead)
                            .foregroundStyle(RSR.labelSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(RSR.labelTertiary)
                }
                .padding(RSRSpace.card)
                .frame(maxWidth: .infinity, alignment: .leading)
                .rsrGlass(.regular, radius: RSRRadius.card, elevation: .card)
            }
            .buttonStyle(.plain)
        }
    }

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: RSRSpace.md) {
            sectionTitle("Setup")

            VStack(spacing: RSRSpace.sm) {
                NavigationLink {
                    ProjectsTab(
                        loginService: loginService,
                        showProfileSheet: $showProfileSheet,
                        wrapInNavigation: false
                    )
                } label: {
                    RSRListRow(
                        title: "Projects",
                        subtitle: "\(appContext.projects.count) configured",
                        systemImage: "folder"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    LabelsTab(
                        loginService: loginService,
                        showProfileSheet: $showProfileSheet,
                        wrapInNavigation: false
                    )
                } label: {
                    RSRListRow(
                        title: "Labels",
                        subtitle: "\(appContext.labels.count) available",
                        systemImage: "tag"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var appSection: some View {
        VStack(alignment: .leading, spacing: RSRSpace.md) {
            sectionTitle("App")

            VStack(spacing: RSRSpace.sm) {
                NavigationLink {
                    RecordingSettingsScreen()
                } label: {
                    RSRListRow(
                        title: "Recording settings",
                        subtitle: recordingSettingsStore.settings.summaryText,
                        systemImage: "waveform"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    DesignSystemShowcaseView()
                } label: {
                    RSRListRow(
                        title: "Design system",
                        subtitle: "Static component preview",
                        systemImage: "paintpalette"
                    )
                }
                .buttonStyle(.plain)

                RSRCard(radius: RSRRadius.control) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notifications")
                                .font(.rsrBody.weight(.semibold))
                                .foregroundStyle(RSR.labelPrimary)

                            Text("Not in scope")
                                .font(.rsrSubhead)
                                .foregroundStyle(RSR.labelSecondary)
                        }

                        Spacer()
                    }
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.rsrCaption)
            .tracking(RSRTracking.eyebrow)
            .foregroundStyle(RSR.labelSecondary)
            .textCase(.uppercase)
    }
}
