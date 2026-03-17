//
//  ContentView.swift
//  Rich sound recorder
//
//  Created by Marius Mathiesen on 04/03/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var loginService = LoginService()
    @State private var isCheckingAuth = true

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
    }
}

#Preview {
    ContentView()
}
