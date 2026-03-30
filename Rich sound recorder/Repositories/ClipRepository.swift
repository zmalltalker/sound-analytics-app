import Foundation

@MainActor
class ClipRepository {
    private let apiService: APIService

    init(loginService: AuthenticationService) {
        self.apiService = APIService(loginService: loginService)
    }

    func listSnippets(labelUID: String) async throws -> [LabelSnippet] {
        let path = "labels/\(labelUID.lowercased())/available_snippets"
        let data = try await apiService.get(path: path)
        return try JSONDecoder().decode([LabelSnippet].self, from: data)
    }

    func downloadSnippet(start: TimeInterval, end: TimeInterval) async throws -> SnippetAudioFile {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "start", value: String(Int(start))),
            URLQueryItem(name: "end", value: String(Int(end)))
        ]
        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""
        let response = try await apiService.getResponse(
            path: "data_download/single\(query)",
            acceptHeader: "audio/wav"
        )

        let tempDirectory = FileManager.default.temporaryDirectory
        let filename = "snippet_\(Int(start))_\(Int(end))_\(UUID().uuidString.lowercased()).wav"
        let fileURL = tempDirectory.appendingPathComponent(filename)
        try response.data.write(to: fileURL, options: .atomic)

        let metadataHeader = response.httpResponse.value(forHTTPHeaderField: "metadata")
        let metadata = parseMetadata(from: metadataHeader)

        return SnippetAudioFile(fileURL: fileURL, metadata: metadata)
    }

    private func parseMetadata(from headerValue: String?) -> SnippetAudioFile.Metadata? {
        guard let headerValue, let data = headerValue.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(SnippetAudioFile.Metadata.self, from: data)
    }
}
