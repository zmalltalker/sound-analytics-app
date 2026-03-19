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
}
