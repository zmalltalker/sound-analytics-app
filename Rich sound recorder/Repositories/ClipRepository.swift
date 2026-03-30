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
}
