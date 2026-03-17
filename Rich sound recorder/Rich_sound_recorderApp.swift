//
//  Rich_sound_recorderApp.swift
//  Rich sound recorder
//
//  Created by Marius Mathiesen on 04/03/2026.
//

import SwiftUI
import MSAL

@main
struct Rich_sound_recorderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Handle URL callback from broker (Authenticator app)
                    print("📱 Received URL: \(url)")
                    MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: nil)
                }
        }
    }
}
