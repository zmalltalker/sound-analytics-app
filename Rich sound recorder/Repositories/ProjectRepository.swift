//
//  ProjectRepository.swift
//  Rich sound recorder
//
//  Created by Marius Mathiesen on 18/03/2026.
//

import Foundation

@MainActor
class ProjectRepository {
    private let apiService: APIService

    private struct UIDsRequest: Encodable {
        let uids: [String]
    }

    init(loginService: AuthenticationService) {
        self.apiService = APIService(loginService: loginService)
    }

    func list() async throws -> [Project] {
        let data = try await apiService.get(path: "projects/list")
        return try JSONDecoder().decode([Project].self, from: data)
    }

    func create(name: String, description: String) async throws {
        let user = try await apiService.whoami()
        let project = Project(
            uid: UUID().uuidString.lowercased(),
            name: name,
            description: description,
            owner_uid: user.oid,
            labels: "[]",
            guests_uids: "[]",
            input_download_response: nil
        )
        try await apiService.post(path: "projects/create", body: project)
    }

    func delete(_ project: Project) async throws {
        try await apiService.postEmpty(path: "projects/\(project.uid)/delete")
    }

    func addLabels(projectUID: String, labelUIDs: [String]) async throws {
        try await apiService.post(
            path: "projects/\(projectUID)/add_labels",
            body: UIDsRequest(uids: labelUIDs)
        )
    }

    func train(projectUID: String) async throws -> TrainingRequest {
        let response = try await apiService.postEmptyResponse(path: "projects/\(projectUID)/train")
        return try JSONDecoder().decode(TrainingRequest.self, from: response.data)
    }

    func trainingStatus(requestUID: String) async throws -> TrainingStatus {
        let data = try await apiService.get(path: "trainer/\(requestUID)/status")

        if let status = try? JSONDecoder().decode(TrainingStatus.self, from: data) {
            return status
        }

        if let response = try? JSONDecoder().decode(TrainingStatusResponse.self, from: data) {
            return response.status
        }

        if let statusString = String(data: data, encoding: .utf8) {
            return TrainingStatus(rawValue: statusString.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        throw APIError.invalidResponse
    }

    func trainingStatusHistory(requestUID: String) async throws -> [TrainingStatusReport] {
        let data = try await apiService.get(path: "trainer/\(requestUID)/status_history")
        return try JSONDecoder().decode([TrainingStatusReport].self, from: data)
    }

    func availableModelVersions(projectUID: String) async throws -> [String] {
        let data = try await apiService.get(path: "projects/\(projectUID)/available_model_versions")

        if let versions = try? JSONDecoder().decode([String].self, from: data) {
            return versions
        }

        let versionObjects = try JSONDecoder().decode([ProjectModelVersion].self, from: data)
        return versionObjects.map(\.version)
    }

    func modelSpecs(projectUID: String) async throws -> ProjectModelSpecs {
        let data = try await apiService.get(path: "projects/\(projectUID)/model_specs")
        return try JSONDecoder().decode(ProjectModelSpecs.self, from: data)
    }

    func downloadIOSModel(
        projectUID: String,
        modelVersion: String,
        samplingRate: Int,
        inputSampleCount: Int
    ) async throws -> URL {
        let path = try pathWithQuery(
            path: "projects/\(projectUID)/get_ios_model",
            queryItems: [
                URLQueryItem(name: "model_version", value: modelVersion),
                URLQueryItem(name: "sampling_rate", value: "\(samplingRate)"),
                URLQueryItem(name: "input_n_samples", value: "\(inputSampleCount)")
            ]
        )
        let data = try await apiService.get(path: path, acceptHeader: "application/zip")
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ios_model_\(projectUID)_\(modelVersion).zip")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func pathWithQuery(path: String, queryItems: [URLQueryItem]) throws -> String {
        var components = URLComponents()
        components.queryItems = queryItems

        guard let query = components.percentEncodedQuery else {
            throw APIError.invalidURL
        }

        return "\(path)?\(query)"
    }

    private struct TrainingStatusResponse: Decodable {
        let status: TrainingStatus
    }

    private struct ProjectModelVersion: Decodable {
        let version: String
    }
}
