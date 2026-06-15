//
//  RecordingRepository.swift
//  Rich sound recorder
//
//  Created by Codex on 19/03/2026.
//

import Foundation

@MainActor
class RecordingRepository {
    private let apiService: APIService

    private struct UploadMetadata: Encodable {
        let label_uid: String
        let start_timestamp: Double
        let end_timestamp: Double
    }

    init(loginService: AuthenticationService) {
        self.apiService = APIService(loginService: loginService)
    }

    func uploadRecording(recording: CompletedRecording, labelUID: String) async throws {
        let metadata = UploadMetadata(
            label_uid: labelUID,
            start_timestamp: recording.startTimestamp,
            end_timestamp: recording.endTimestamp
        )

        let metadataData = try JSONEncoder().encode(metadata)
        guard let metadataJSON = String(data: metadataData, encoding: .utf8) else {
            throw APIError.invalidResponse
        }

        _ = try await apiService.postMultipart(
            path: "data_upload/single",
            fields: ["metadata": metadataJSON],
            fileFieldName: "file",
            fileURL: recording.fileURL,
            fileName: recording.fileURL.lastPathComponent,
            mimeType: mimeType(for: recording.fileURL)
        )
    }

    private func mimeType(for fileURL: URL) -> String {
        switch fileURL.pathExtension.lowercased() {
        case "wav":
            return "audio/wav"
        case "m4a":
            return "audio/m4a"
        case "aac":
            return "audio/aac"
        case "caf":
            return "audio/x-caf"
        default:
            return "application/octet-stream"
        }
    }
}
