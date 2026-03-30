import Foundation

struct SnippetAudioFile {
    struct Metadata: Codable {
        let start: TimeInterval
        let end: TimeInterval
    }

    let fileURL: URL
    let metadata: Metadata?
}
