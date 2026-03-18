//
//  APIService.swift
//  Rich sound recorder
//
//  Created by Marius Mathiesen on 17/03/2026.
//

import Foundation

@MainActor
class APIService {
    let baseURL = "https://webrecorder.rest.dev.edgeaudioanalytics.no/rest/"
    private let loginService: AuthenticationService

    init(loginService: AuthenticationService) {
        self.loginService = loginService
    }

    func get(path: String) async throws -> Data {
        print("🔍 API GET Request Debug:")
        print("   Path: \(path)")
        print("   Is logged in: \(loginService.isLoggedIn)")

        // Ensure we have a token
        guard loginService.isLoggedIn else {
            print("   ❌ Not authenticated")
            throw APIError.notAuthenticated
        }

        // Get fresh token (uses cached token or refreshes silently)
        print("   🔐 Acquiring access token...")
        let token = await getAccessToken()

        if let token = token {
            print("   ✅ Token acquired: \(token.prefix(20))...")
            print("   Token length: \(token.count) chars")
        } else {
            print("   ❌ Failed to acquire token")
            throw APIError.noToken
        }

        guard let token = token else {
            throw APIError.noToken
        }

        // Build URL
        guard let url = URL(string: baseURL + path) else {
            print("   ❌ Invalid URL: \(baseURL + path)")
            throw APIError.invalidURL
        }

        // Create request with auth header
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        print("   🌐 Sending GET request to: \(url)")
        print("   Headers:")
        print("     Authorization: Bearer \(token.prefix(20))...")
        print("     Accept: application/json")

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            print("   ❌ Invalid HTTP response")
            throw APIError.invalidResponse
        }

        print("   📥 Response received:")
        print("     Status: \(httpResponse.statusCode)")
        print("     Headers: \(httpResponse.allHeaderFields)")

        if let responseString = String(data: data, encoding: .utf8) {
            print("     Body: \(responseString.prefix(200))")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            print("   ❌ HTTP Error \(httpResponse.statusCode)")
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        return data
    }

    func whoami() async throws -> User {
        let data = try await get(path: "whoami")
        return try JSONDecoder().decode(User.self, from: data)
    }

    func postEmpty(path: String) async throws {
        guard loginService.isLoggedIn else { throw APIError.notAuthenticated }
        guard let token = await getAccessToken() else { throw APIError.noToken }
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200...299).contains(httpResponse.statusCode) else {
            if let body = String(data: data, encoding: .utf8) {
                print("❌ POST \(path) \(httpResponse.statusCode): \(body)")
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    func post<Body: Encodable>(path: String, body: Body) async throws {
        guard loginService.isLoggedIn else { throw APIError.notAuthenticated }
        guard let token = await getAccessToken() else { throw APIError.noToken }
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200...299).contains(httpResponse.statusCode) else {
            if let body = String(data: data, encoding: .utf8) {
                print("❌ POST \(path) \(httpResponse.statusCode): \(body)")
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
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
