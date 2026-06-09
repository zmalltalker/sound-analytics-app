//
//  APIService.swift
//  Rich sound recorder
//
//  Created by Marius Mathiesen on 17/03/2026.
//

import Foundation

@MainActor
class APIService {
    struct APIResponse {
        let data: Data
        let httpResponse: HTTPURLResponse
    }

    let baseURL = "https://webrecorder.rest.dev.edgeaudioanalytics.no/rest/"
    private let loginService: AuthenticationService
    private let isLoggingEnabled = true

    init(loginService: AuthenticationService) {
        self.loginService = loginService
    }

    func get(path: String, acceptHeader: String? = "application/json") async throws -> Data {
        try await getResponse(path: path, acceptHeader: acceptHeader).data
    }

    func getAbsoluteURLString(_ urlString: String, acceptHeader: String? = "application/json") async throws -> Data {
        try await getAbsoluteURLResponse(urlString, acceptHeader: acceptHeader).data
    }

    func getResponse(path: String, acceptHeader: String? = "application/json") async throws -> APIResponse {
        guard loginService.isLoggedIn else {
            log("GET \(path) blocked: not authenticated")
            throw APIError.notAuthenticated
        }

        let token = await getAccessToken()
        guard let token else {
            log("GET \(path) blocked: token unavailable")
            throw APIError.noToken
        }

        guard let url = URL(string: baseURL + path) else {
            log("GET \(path) failed: invalid URL")
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let acceptHeader {
            request.setValue(acceptHeader, forHTTPHeaderField: "Accept")
        }

        logRequest("GET", path: path, details: acceptHeader.map { "accept=\($0)" })

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            log("GET \(path) failed: invalid HTTP response")
            throw APIError.invalidResponse
        }

        logResponse("GET", path: path, response: httpResponse, data: data)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        return APIResponse(data: data, httpResponse: httpResponse)
    }

    func getAbsoluteURLResponse(_ urlString: String, acceptHeader: String? = "application/json") async throws -> APIResponse {
        guard loginService.isLoggedIn else {
            log("GET \(urlString) blocked: not authenticated")
            throw APIError.notAuthenticated
        }

        let token = await getAccessToken()
        guard let token else {
            log("GET \(urlString) blocked: token unavailable")
            throw APIError.noToken
        }

        guard let url = URL(string: urlString) else {
            log("GET \(urlString) failed: invalid URL")
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let acceptHeader {
            request.setValue(acceptHeader, forHTTPHeaderField: "Accept")
        }

        logRequest("GET", path: urlString, details: acceptHeader.map { "accept=\($0)" })

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            log("GET \(urlString) failed: invalid HTTP response")
            throw APIError.invalidResponse
        }

        logResponse("GET", path: urlString, response: httpResponse, data: data)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        return APIResponse(data: data, httpResponse: httpResponse)
    }

    func whoami() async throws -> User {
        let data = try await get(path: "whoami")
        return try JSONDecoder().decode(User.self, from: data)
    }

    func postEmpty(path: String) async throws {
        _ = try await postEmptyResponse(path: path)
    }

    func postEmptyResponse(path: String) async throws -> APIResponse {
        guard loginService.isLoggedIn else { throw APIError.notAuthenticated }
        guard let token = await getAccessToken() else { throw APIError.noToken }
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        logRequest("POST", path: path, details: "empty-body")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        logResponse("POST", path: path, response: httpResponse, data: data)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        return APIResponse(data: data, httpResponse: httpResponse)
    }

    func postResponse(path: String) async throws -> Data {
        guard loginService.isLoggedIn else { throw APIError.notAuthenticated }
        guard let token = await getAccessToken() else { throw APIError.noToken }
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        logRequest("POST", path: path, details: "empty-body")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        logResponse("POST", path: path, response: httpResponse, data: data)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        return data
    }

    func post<Body: Encodable>(path: String, body: Body) async throws {
        _ = try await postResponse(path: path, body: body)
    }

    func postResponse<Body: Encodable>(path: String, body: Body) async throws -> APIResponse {
        guard loginService.isLoggedIn else { throw APIError.notAuthenticated }
        guard let token = await getAccessToken() else { throw APIError.noToken }
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        logRequest("POST", path: path, details: request.httpBody.flatMap(jsonSummary(from:)) ?? "json-body")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        logResponse("POST", path: path, response: httpResponse, data: data)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        return APIResponse(data: data, httpResponse: httpResponse)
    }

    func postMultipart(
        path: String,
        fields: [String: String],
        fileFieldName: String,
        fileURL: URL,
        fileName: String,
        mimeType: String
    ) async throws -> APIResponse {
        guard loginService.isLoggedIn else { throw APIError.notAuthenticated }
        guard let token = await getAccessToken() else { throw APIError.noToken }
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        let boundary = "Boundary-\(UUID().uuidString.lowercased())"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        for (name, value) in fields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }

        let fileData = try Data(contentsOf: fileURL)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(fileName)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")

        let fieldSummary = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
        logRequest(
            "POST multipart",
            path: path,
            details: "file=\(fileName) (\(fileData.count) bytes, \(mimeType)), fields=[\(fieldSummary)]"
        )
        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        logResponse("POST multipart", path: path, response: httpResponse, data: data)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        return APIResponse(data: data, httpResponse: httpResponse)
    }

    private func getAccessToken() async -> String? {
        await withCheckedContinuation { continuation in
            loginService.acquireTokenSilently { token in
                continuation.resume(returning: token)
            }
        }
    }

    private func log(_ message: String) {
        guard isLoggingEnabled else { return }
        print("API \(message)")
    }

    private func logRequest(_ method: String, path: String, details: String?) {
        guard isLoggingEnabled else { return }
        if let details, !details.isEmpty {
            print("API ↑ \(method) \(path) | \(details)")
        } else {
            print("API ↑ \(method) \(path)")
        }
    }

    private func logResponse(_ method: String, path: String, response: HTTPURLResponse, data: Data) {
        guard isLoggingEnabled else { return }

        let contentType = response.value(forHTTPHeaderField: "Content-Type") ?? "unknown"
        let preview = responsePreview(from: data)
        print("API ↓ \(method) \(path) | status=\(response.statusCode) contentType=\(contentType) body=\(preview)")
    }

    private func responsePreview(from data: Data) -> String {
        if data.isEmpty {
            return "<empty>"
        }

        if let string = String(data: data, encoding: .utf8)?
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ") {
            return String(string.prefix(240))
        }

        return "<\(data.count) bytes binary>"
    }

    private func jsonSummary(from data: Data) -> String {
        if let string = String(data: data, encoding: .utf8)?
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ") {
            return String(string.prefix(240))
        }

        return "json-body \(data.count) bytes"
    }
}

private extension Data {
    mutating func append(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        append(data)
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
