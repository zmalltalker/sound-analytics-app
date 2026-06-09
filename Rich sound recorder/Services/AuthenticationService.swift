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
class AuthenticationService {
    private var application: MSALPublicClientApplication?
    private var currentAccount: MSALAccount?
    private(set) var isLoggedIn: Bool = false
    private(set) var username: String?

    private static let TENANT_ID = "7fd16dc5-af0e-4826-adea-022e56bd9f22"
//    private let scopes = ["User.Read"]
    private let scopes = ["api://7fd16dc5-af0e-4826-adea-022e56bd9f22/user_impersonation"]

    init() {
        do {
            let authority = try MSALAADAuthority(
                url: URL(string: "https://login.microsoftonline.com/7c595a94-ec31-4674-bd4e-f388f91c5b72/v2.0")!
            )

            let config = MSALPublicClientApplicationConfig(
                clientId: "7fd16dc5-af0e-4826-adea-022e56bd9f22",
                redirectUri: "msauth.ai.resonyx.ios-recorder://auth",
                authority: authority
            )
            config.cacheConfig.keychainSharingGroup = "ai.resonyx.ios-recorder"
            application = try MSALPublicClientApplication(configuration: config)
            print("Auth initialized")

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
                print("Auth restored account: \(account.username ?? "unknown")")
            } else {
                print("Auth: no cached account")
            }
        } catch {
            print("Auth restore failed: \(error)")
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

        let webviewParameters = MSALWebviewParameters(authPresentationViewController: viewController)
        webviewParameters.webviewType = .authenticationSession  // Forces ASWebAuthenticationSession

        let parameters = MSALInteractiveTokenParameters(
            scopes: scopes,
            webviewParameters: webviewParameters
        )
        parameters.promptType = .selectAccount  // Don't use broker

        print("Auth login started")

        application.acquireToken(with: parameters) { [weak self] result, error in
            if let error = error {
                print("Auth login failed: \(error)")
                return
            }

            guard let result = result else {
                print("Auth login failed: empty result")
                return
            }

            print("Auth login succeeded: \(result.account.username ?? "unknown")")

            guard let self = self else { return }
            Task { @MainActor in
                self.currentAccount = result.account
                self.username = result.account.username
                self.isLoggedIn = true
            }
        }
    }

    /// Silent login - uses cached refresh token from Keychain
    func acquireTokenSilently(completion: @escaping (String?) -> Void) {
        guard let application = application,
              let account = currentAccount else {
            print("Auth token skipped: no account")
            completion(nil)
            return
        }

        let parameters = MSALSilentTokenParameters(scopes: scopes, account: account)

        application.acquireTokenSilent(with: parameters) { result, error in
            if let error = error {
                print("Auth token refresh failed: \(error)")
                completion(nil)
                return
            }

            guard let result = result else {
                print("Auth token refresh failed: empty result")
                completion(nil)
                return
            }

            print("Auth token refreshed")
            completion(result.accessToken)
        }
    }

    /// Logout - removes tokens from Keychain
    func logout() {
        guard let application = application,
              let account = currentAccount else {
            print("Auth logout skipped: no account")
            return
        }

        do {
            try application.remove(account)
            currentAccount = nil
            username = nil
            isLoggedIn = false
            print("Auth logout succeeded")
        } catch {
            print("Auth logout failed: \(error)")
        }
    }

    /// Get token information for debug display
    func getTokenInfo() -> TokenInfo? {
        guard let account = currentAccount else { return nil }

        return TokenInfo(
            username: account.username,
            homeAccountId: account.homeAccountId?.identifier ?? "Unknown",
            environment: account.environment
        )
    }
}

struct TokenInfo {
    let username: String?
    let homeAccountId: String
    let environment: String?
}
