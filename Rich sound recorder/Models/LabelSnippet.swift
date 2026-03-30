import Foundation

struct LabelSnippet: Identifiable, Codable {
    let start: TimeInterval
    let end: TimeInterval

    var id: String { "\(start)-\(end)" }
    var duration: TimeInterval { max(0, end - start) }
}
