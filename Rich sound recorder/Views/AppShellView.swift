import SwiftUI

struct MainView: View {
    let loginService: AuthenticationService
    let detectionService: any EventDetectionServicing
    let detectionModelProvider: any DetectionModelProviding
    @State private var showProfileSheet = false

    init(
        loginService: AuthenticationService,
        detectionService: any EventDetectionServicing = BundledEventDetectionService(),
        detectionModelProvider: any DetectionModelProviding = BundledDetectionModelProvider()
    ) {
        self.loginService = loginService
        self.detectionService = detectionService
        self.detectionModelProvider = detectionModelProvider
    }

    var body: some View {
        TabView {
            TrainingTab(loginService: loginService, showProfileSheet: $showProfileSheet)
                .tabItem {
                    Label("Training", systemImage: "waveform")
                }

            DetectionTab(
                showProfileSheet: $showProfileSheet,
                detectionService: detectionService,
                modelProvider: detectionModelProvider
            )
            .tabItem {
                Label("Detection", systemImage: "dot.scope")
            }

            MoreTab(loginService: loginService, showProfileSheet: $showProfileSheet)
                .tabItem {
                    Label("More", systemImage: "square.grid.2x2")
                }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showProfileSheet) {
            ProfileSheet(loginService: loginService)
        }
    }
}

#Preview {
    MainView(loginService: AuthenticationService())
}
