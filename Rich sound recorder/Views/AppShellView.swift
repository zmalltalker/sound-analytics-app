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
                Color.black.ignoresSafeArea()

                activeSectionView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                AppSectionBar(selectedSection: $selectedSection)
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
    private let sections: [AppSection] = [.train, .detect, .models, .settings]

    @Binding var selectedSection: AppSection

    var body: some View {
        HStack(spacing: 6) {
            ForEach(sections, id: \.self) { section in
                sectionButton(section)
            }
        }
        .padding(8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial.opacity(0.9))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 14, y: 8)
    }

    private func sectionButton(_ section: AppSection) -> some View {
        let isSelected = selectedSection == section

        return Button {
            selectedSection = section
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage(for: section))
                    .font(.body)
                Text(title(for: section))
                    .font(.footnote)
            }
            .foregroundStyle(isSelected ? .black : Color.white.opacity(0.88))
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .contentShape(Rectangle())
            .background(
                Capsule()
                    .fill(isSelected ? Color.white.opacity(0.92) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func title(for section: AppSection) -> String {
        switch section {
        case .train:
            return "Train"
        case .detect:
            return "Detect"
        case .models:
            return "Models"
        case .settings:
            return "Settings"
        }
    }

    private func systemImage(for section: AppSection) -> String {
        switch section {
        case .train:
            return "waveform"
        case .detect:
            return "dot.scope"
        case .models:
            return "square.stack.3d.up"
        case .settings:
            return "gearshape"
        }
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
