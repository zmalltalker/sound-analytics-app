import SwiftUI

struct MainView: View {
    let loginService: AuthenticationService
    let detectionService: any EventDetectionServicing

    @State private var appContext: RedesignAppContext
    @State private var selectedSection: AppSection = .train
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
                RSR.canvas.ignoresSafeArea()

                activeSectionView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                AppSectionBar(selectedSection: $selectedSection)
                .padding(.bottom, 8)
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
    }

    @ViewBuilder
    private var activeSectionView: some View {
        switch selectedSection {
        case .train:
            TrainWorkspaceView(
                loginService: loginService,
                showProjectSwitcher: $showProjectSwitcher,
                onViewModels: {
                    selectedSection = .models
                },
                onOpenLabels: openLabelsSetup,
                onLeaveRunning: {}
            )
        case .detect:
            DetectWorkspaceView(
                detectionService: detectionService,
                showProjectSwitcher: $showProjectSwitcher,
                onOpenModels: {
                    selectedSection = .models
                },
                onOpenTrain: {
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
        selectedSection = .settings
        setupDestination = .projects
    }

    private func openLabelsSetup() {
        selectedSection = .settings
        setupDestination = .labels
    }
}

private struct AppSectionBar: View {
    @Binding var selectedSection: AppSection

    var body: some View {
        RSRTabBar(tabs: RSRTabBar.standardTabs, selection: selectionIndex)
    }

    private var selectionIndex: Binding<Int> {
        Binding(
            get: {
                switch selectedSection {
                case .train: return 0
                case .detect: return 1
                case .models: return 2
                case .settings: return 3
                }
            },
            set: { newValue in
                switch newValue {
                case 0: selectedSection = .train
                case 1: selectedSection = .detect
                case 2: selectedSection = .models
                default: selectedSection = .settings
                }
            }
        )
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
