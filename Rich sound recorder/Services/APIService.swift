//
//  APIService.swift
//  Rich sound recorder
//
//  Created by Marius Mathiesen on 17/03/2026.
//

import Foundation

@MainActor
class APIService {
    let baseURL = "https://webrecorder.rest.dev.edgeaudioanalytics.no/"
    private let loginService: AuthenticationService

    init(loginService: AuthenticationService) {
        self.loginService = loginService
    }

    func get(path: String) async throws -> Data {
        // Ensure we have a token
        guard loginService.isLoggedIn else {
            throw APIError.notAuthenticated
        }

        // Get fresh token (uses cached token or refreshes silently)
        let token = await getAccessToken()
        guard let token = token else {
            throw APIError.noToken
        }

        // Build URL
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        // Create request with auth header
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        print("🌐 GET \(url)")
        print("   Authorization: Bearer \(token.prefix(20))...")

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        print("✅ Response: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        return data
    }

    private func getAccessToken() async -> String? {
        await withCheckedContinuation { continuation in
            loginService.acquireTokenSilently { token in
                continuation.resume(returning: token)
            }
        }
    }
}

enum APIError: LocalizedError {
    case notAuthenticated
    case noToken
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .noToken:
            return "Could not acquire access token"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        }
    }
}
