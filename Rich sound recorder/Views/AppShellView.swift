import SwiftUI

struct MainView: View {
    let loginService: AuthenticationService
    let detectionService: any EventDetectionServicing

    @State private var appContext: RedesignAppContext
    @State private var selectedSection: AppSection = .train
    @State private var showingHome = true
    @State private var showProjectSwitcher = false
    @State private var showProfileSheet = false
    @State private var setupDestination: SetupDestination?

    init(
        loginService: AuthenticationService,
        detectionService: any EventDetectionServicing = BundledEventDetectionService(),
        detectionModelProvider _: any DetectionModelProviding = BundledDetectionModelProvider()
    ) {
        self.loginService = loginService
        self.detectionService = detectionService
        _appContext = State(initialValue: RedesignAppContext(loginService: loginService))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()

                Group {
                    if showingHome {
                        HomeLaunchView(
                            selectedSection: $selectedSection,
                            showingHome: $showingHome,
                            showProjectSwitcher: $showProjectSwitcher,
                            onOpenProjects: openProjectsSetup
                        )
                    } else {
                        activeSectionView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                AppSectionBar(
                    selectedSection: $selectedSection,
                    showingHome: $showingHome
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .navigationDestination(item: $setupDestination) { destination in
                switch destination {
                case .projects:
                    ProjectsTab(
                        loginService: loginService,
                        showProfileSheet: $showProfileSheet,
                        wrapInNavigation: false
                    )
                case .labels:
                    LabelsTab(
                        loginService: loginService,
                        showProfileSheet: $showProfileSheet,
                        wrapInNavigation: false
                    )
                }
            }
            .sheet(isPresented: $showProjectSwitcher) {
                ProjectSwitcherSheet {
                    openProjectsSetup()
                }
                .environment(appContext)
            }
            .sheet(isPresented: $showProfileSheet) {
                ProfileSheet(loginService: loginService)
            }
            .task {
                await appContext.refreshAll()
            }
        }
        .environment(appContext)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var activeSectionView: some View {
        switch selectedSection {
        case .train:
            TrainWorkspaceView(
                loginService: loginService,
                showProjectSwitcher: $showProjectSwitcher,
                onViewModels: {
                    showingHome = false
                    selectedSection = .models
                },
                onOpenLabels: openLabelsSetup,
                onLeaveRunning: { showingHome = true }
            )
        case .detect:
            DetectWorkspaceView(
                detectionService: detectionService,
                showProjectSwitcher: $showProjectSwitcher,
                onOpenModels: {
                    showingHome = false
                    selectedSection = .models
                },
                onOpenTrain: {
                    showingHome = false
                    selectedSection = .train
                }
            )
        case .models:
            ModelsWorkspaceView(showProjectSwitcher: $showProjectSwitcher)
        case .settings:
            SettingsWorkspaceView(
                loginService: loginService,
                showProfileSheet: $showProfileSheet,
                destination: $setupDestination
            )
        }
    }

    private func openProjectsSetup() {
        showingHome = false
        selectedSection = .settings
        setupDestination = .projects
    }

    private func openLabelsSetup() {
        showingHome = false
        selectedSection = .settings
        setupDestination = .labels
    }
}

private struct AppSectionBar: View {
    @Binding var selectedSection: AppSection
    @Binding var showingHome: Bool

    var body: some View {
        HStack(spacing: 8) {
            sectionButton(.train, title: "Train", systemImage: "waveform")
            sectionButton(.detect, title: "Detect", systemImage: "dot.scope")
            sectionButton(.models, title: "Models", systemImage: "square.stack.3d.up")
            sectionButton(.settings, title: "Settings", systemImage: "gearshape")
        }
        .padding(8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial.opacity(0.85))
        )
    }

    private func sectionButton(_ section: AppSection, title: String, systemImage: String) -> some View {
        Button {
            if selectedSection == section, !showingHome {
                showingHome = true
            } else {
                selectedSection = section
                showingHome = false
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(selectedSection == section ? .black : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(selectedSection == section ? Color.white : .clear)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainView(loginService: AuthenticationService())
}

enum SetupDestination: String, Hashable, Identifiable {
    case projects
    case labels

    var id: String { rawValue }
}
