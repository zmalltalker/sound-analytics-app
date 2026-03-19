//
//  LabelRepository.swift
//  Rich sound recorder
//
//  Created by Marius Mathiesen on 18/03/2026.
//

import Foundation

@MainActor
class LabelRepository {
    private let apiService: APIService

    init(loginService: AuthenticationService) {
        self.apiService = APIService(loginService: loginService)
    }

    func create(name: String, description: String = "", durationSeconds: Double = 0) async throws {
        let user = try await apiService.whoami()
        let newUID = UUID().uuidString.lowercased()
        let label = RecorderLabel(
            uid: newUID,
            guid: newUID,
            name: name,
            user_id: user.oid,
            duration: durationSeconds,
            description: description
        )
        try await apiService.post(path: "labels/create", body: [label])
    }

    func list() async throws -> [RecorderLabel] {
        let data = try await apiService.get(path: "labels/get")
        return try JSONDecoder().decode([RecorderLabel].self, from: data)
    }
}
