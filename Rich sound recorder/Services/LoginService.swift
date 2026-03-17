//
//  LoginService.swift
//  Rich sound recorder
//
//  Created by Marius Mathiesen on 17/03/2026.
//

import Foundation
import MSAL
import UIKit

@MainActor
class LoginService {
    private var application: MSALPublicClientApplication?

    init() {
        do {
            let authority = try MSALAADAuthority(
                url: URL(string: "https://login.microsoftonline.com/common")!
            )

            let config = MSALPublicClientApplicationConfig(
                clientId: "7fd16dc5-af0e-4826-adea-022e56bd9f22",
                redirectUri: "msauth.ai.resonyx.ios-recorder://auth",
                authority: authority
            )
            application = try MSALPublicClientApplication(configuration: config)
            print("✅ MSAL application initialized")
        } catch {
            print("❌ Failed to create MSAL application: \(error)")
        }
    }

    func login() {
        guard let application = application else {
            print("❌ MSAL application not initialized")
            return
        }

        // Get the current window scene to present the web view
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let viewController = windowScene.windows.first?.rootViewController else {
            print("❌ Could not find root view controller")
            return
        }

        let parameters = MSALInteractiveTokenParameters(
            scopes: ["User.Read"],
            webviewParameters: MSALWebviewParameters(authPresentationViewController: viewController)
        )

        print("🔐 Starting interactive login...")

        application.acquireToken(with: parameters) { result, error in
            if let error = error {
                print("❌ Login failed: \(error)")
                return
            }

            guard let result = result else {
                print("❌ No result from login")
                return
            }

            print("✅ Login successful!")
            print("   Account: \(result.account.username ?? "unknown")")
            print("   Token: \(result.accessToken)...")
        }
    }
}
