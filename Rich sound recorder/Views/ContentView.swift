//
//  ContentView.swift
//  Rich sound recorder
//
//  Created by Marius Mathiesen on 04/03/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var loginService = AuthenticationService()
    @State private var isCheckingAuth = true
    @State private var hasAttemptedOpenAPIDownload = false

    var body: some View {
        Group {
            if isCheckingAuth {
                // Show loading while checking auth state
                ZStack {
                    Color.black.ignoresSafeArea()
                    ProgressView()
                        .tint(.cyan)
                }
            } else if loginService.isLoggedIn {
                MainView(loginService: loginService)
            } else {
                WelcomeView(loginService: loginService)
            }
        }
        .task {
            // Check authentication state on launch
            loginService.loadCurrentAccount()
            isCheckingAuth = false
        }
        .task(id: loginService.isLoggedIn) {
            guard loginService.isLoggedIn else {
                hasAttemptedOpenAPIDownload = false
                return
            }

            guard !hasAttemptedOpenAPIDownload else { return }
            hasAttemptedOpenAPIDownload = true
            await downloadOpenAPISpec()
        }
    }

    private func downloadOpenAPISpec() async {
        let apiService = APIService(loginService: loginService)

        do {
            let data = try await apiService.getAbsoluteURLString(
                "https://webrecorder.rest.dev.edgeaudioanalytics.no/rest/openapi.json",
                acceptHeader: "application/json"
            )

            let docsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = docsDirectory.appendingPathComponent("openapi.json")
            try data.write(to: fileURL, options: .atomic)
            print("OpenAPI spec saved to \(fileURL.path)")
        } catch {
            print("OpenAPI spec download failed: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ContentView()
}
