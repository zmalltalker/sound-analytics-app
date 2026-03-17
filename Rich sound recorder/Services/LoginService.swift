//
//  LoginService.swift
//  Rich sound recorder
//
//  Created by Marius Mathiesen on 17/03/2026.
//

import Foundation
import MSAL
import UIKit
import SwiftUI

@MainActor
@Observable
class LoginService {
    private var application: MSALPublicClientApplication?
    private var currentAccount: MSALAccount?
    private(set) var isLoggedIn: Bool = false
    private(set) var username: String?

    private let scopes = ["User.Read"]

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
            config.cacheConfig.keychainSharingGroup = "ai.resonyx.ios-recorder"
            application = try MSALPublicClientApplication(configuration: config)
            print("✅ MSAL application initialized")

            // Check if user is already logged in
            loadCurrentAccount()
        } catch {
            print("❌ Failed to create MSAL application: \(error)")
        }
    }

    /// Load the current account from the cache (tokens stored in Keychain by MSAL)
    func loadCurrentAccount() {
        guard let application = application else { return }

        do {
            let accounts = try application.allAccounts()
            if let account = accounts.first {
                currentAccount = account
                username = account.username
                isLoggedIn = true
                print("✅ Found cached account: \(account.username ?? "unknown")")
            } else {
                print("ℹ️ No cached account found")
            }
        } catch {
            print("⚠️ Could not load cached account: \(error)")
        }
    }

    /// Interactive login - shows browser
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
            scopes: scopes,
            webviewParameters: MSALWebviewParameters(authPresentationViewController: viewController)
        )

        print("🔐 Starting interactive login...")

        application.acquireToken(with: parameters) { [weak self] result, error in
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
            print("   Token: \(result.accessToken.prefix(20))...")

            self?.currentAccount = result.account
            self?.username = result.account.username
            self?.isLoggedIn = true
        }
    }

    /// Silent login - uses cached refresh token from Keychain
    func acquireTokenSilently(completion: @escaping (String?) -> Void) {
        guard let application = application,
              let account = currentAccount else {
            print("❌ No account to acquire token for")
            completion(nil)
            return
        }

        let parameters = MSALSilentTokenParameters(scopes: scopes, account: account)

        application.acquireTokenSilent(with: parameters) { result, error in
            if let error = error {
                print("⚠️ Silent token acquisition failed: \(error)")
                completion(nil)
                return
            }

            guard let result = result else {
                completion(nil)
                return
            }

            print("✅ Token acquired silently")
            completion(result.accessToken)
        }
    }

    /// Logout - removes tokens from Keychain
    func logout() {
        guard let application = application,
              let account = currentAccount else {
            print("⚠️ No account to logout")
            return
        }

        do {
            try application.remove(account)
            currentAccount = nil
            username = nil
            isLoggedIn = false
            print("✅ Logged out successfully")
        } catch {
            print("❌ Logout failed: \(error)")
        }
    }
}
