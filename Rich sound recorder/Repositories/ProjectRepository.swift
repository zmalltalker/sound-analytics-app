//
//  ProjectRepository.swift
//  Rich sound recorder
//
//  Created by Marius Mathiesen on 18/03/2026.
//

import Foundation

@MainActor
class ProjectRepository {
    private let baseURL = "https://webrecorder.rest.dev.edgeaudioanalytics.no/rest/"
    private let apiService: APIService

    private struct DownloadedModelMetadata: Codable {
        let displayName: String
        let labelNames: [String]
        let modelVersion: String
        let projectUID: String
    }

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

    func availableModelVersions(projectUID: String) async throws -> [String] {
        let data = try await apiService.get(
            path: "projects/\(projectUID)/available_model_versions"
        )
        return try JSONDecoder().decode([String].self, from: data)
    }

    func statistics(projectUID: String? = nil) async throws -> [String: Int] {
        let path: String
        if let projectUID {
            path = "statistics?project_uid=\(projectUID)"
        } else {
            path = "statistics"
        }

        let data = try await apiService.get(path: path)
        return try JSONDecoder().decode([String: Int].self, from: data)
    }

    func recordingsCount(projectUID: String? = nil) async throws -> Int {
        let path: String
        if let projectUID {
            path = "statistics/recordings?project_uid=\(projectUID)"
        } else {
            path = "statistics/recordings"
        }

        let data = try await apiService.get(path: path)
        return try JSONDecoder().decode(Int.self, from: data)
    }

    func modelSpecs(projectUID: String, modelVersion: String) async throws -> ProjectModelSpecs {
        let escapedModelVersion = modelVersion.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? modelVersion
        let data = try await apiService.get(
            path: "projects/\(projectUID)/model_specs?model_version=\(escapedModelVersion)"
        )
        return try JSONDecoder().decode(ProjectModelSpecs.self, from: data)
    }

    func iosModelDownloadURLString(
        projectUID: String,
        modelVersion: String,
        samplingRate: Int,
        inputNSamples: Int
    ) -> String {
        let path = iosModelDownloadPath(
            projectUID: projectUID,
            modelVersion: modelVersion,
            samplingRate: samplingRate,
            inputNSamples: inputNSamples
        )
        return baseURL + path
    }

    func downloadIOSModel(
        projectUID: String,
        modelVersion: String,
        samplingRate: Int,
        inputNSamples: Int,
        displayName: String? = nil,
        labelNames: [String] = []
    ) async throws -> URL {
        let data = try await apiService.get(
            path: iosModelDownloadPath(
                projectUID: projectUID,
                modelVersion: modelVersion,
                samplingRate: samplingRate,
                inputNSamples: inputNSamples
            ),
            acceptHeader: nil
        )

        let docsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "model_\(projectUID)_\(modelVersion).zip"
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        let fileURL = docsDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)

        if let displayName {
            let metadata = DownloadedModelMetadata(
                displayName: displayName,
                labelNames: labelNames,
                modelVersion: modelVersion,
                projectUID: projectUID
            )
            let metadataURL = fileURL.appendingPathExtension("metadata.json")
            let metadataData = try JSONEncoder().encode(metadata)
            try metadataData.write(to: metadataURL, options: .atomic)
        }

        return fileURL
    }

    func startTraining(projectUID: String) async throws -> TrainingRequest {
        let data = try await apiService.postResponse(path: "projects/\(projectUID)/train")
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let requestUID = object["request_uid"] as? String, !requestUID.isEmpty {
                return TrainingRequest(requestUID: requestUID)
            }
            if let requestUID = object["training_request_uid"] as? String, !requestUID.isEmpty {
                return TrainingRequest(requestUID: requestUID)
            }
            if let requestUID = object["uid"] as? String, !requestUID.isEmpty {
                return TrainingRequest(requestUID: requestUID)
            }
        }

        guard let rawValue = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"")),
              !rawValue.isEmpty else {
            throw APIError.invalidResponse
        }
        return TrainingRequest(requestUID: rawValue)
    }

    func trainingStatus(trainingRequestUID: String) async throws -> TrainingStatusSnapshot {
        let data = try await apiService.get(path: "trainer/\(trainingRequestUID)/status")
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let status = object["status"] as? String,
           !status.isEmpty {
            return TrainingStatusSnapshot(status: status)
        }

        guard let rawValue = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"")),
              !rawValue.isEmpty else {
            throw APIError.invalidResponse
        }
        return TrainingStatusSnapshot(status: rawValue)
    }

    func trainingStatusHistory(trainingRequestUID: String) async throws -> [TrainingStatusReport] {
        let data = try await apiService.get(path: "trainer/\(trainingRequestUID)/status_history")
        do {
            return try JSONDecoder().decode([TrainingStatusReport].self, from: data)
        } catch {
            let rawPayload = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes binary>"
            print(
                "Training status history decode failed | request=\(trainingRequestUID) | error=\(error.localizedDescription) | raw=\(rawPayload)"
            )
            throw error
        }
    }

    private func iosModelDownloadPath(
        projectUID: String,
        modelVersion: String,
        samplingRate: Int,
        inputNSamples: Int
    ) -> String {
        let escapedModelVersion = modelVersion.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? modelVersion
        return "projects/\(projectUID)/get_ios_model?model_version=\(escapedModelVersion)&sampling_rate=\(samplingRate)&input_n_samples=\(inputNSamples)"
    }
}
