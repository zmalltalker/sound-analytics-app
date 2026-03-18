import Foundation

// MARK: - Burst Analysis File Format (v1.0)
//
// JSON schema exchanged with the server for burst-mode recordings.
// The server produces this document after analyzing a long recording;
// the app lets the user trim and label chunks, then re-uploads it.

struct BurstAnalysis: Codable, Identifiable {
    var id: UUID
    var version: String                 // "1.0"
    var source: String                  // original recording filename
    var duration: Double                // total recording duration in seconds
    var sampleRate: Double
    var analyzedAt: Date
    var chunks: [BurstChunk]

    init(source: String, duration: Double, sampleRate: Double, chunks: [BurstChunk] = []) {
        self.id = UUID()
        self.version = "1.0"
        self.source = source
        self.duration = duration
        self.sampleRate = sampleRate
        self.analyzedAt = Date()
        self.chunks = chunks
    }
}

struct BurstChunk: Codable, Identifiable {
    var id: UUID
    var startTime: Double               // seconds from beginning of recording
    var endTime: Double                 // seconds from beginning of recording
    var label: String                   // user-assigned label, e.g. "kick", "snare"
    var characteristics: ChunkCharacteristics?

    var duration: Double { endTime - startTime }

    init(startTime: Double, endTime: Double, label: String = "",
         characteristics: ChunkCharacteristics? = nil) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.label = label
        self.characteristics = characteristics
    }
}

struct ChunkCharacteristics: Codable {
    var dominantFrequency: Double?      // Hz
    var energy: Double?                 // 0.0 – 1.0 normalised RMS
    var spectralCentroid: Double?       // Hz
    var tags: [String]                  // server-supplied descriptive tags

    init(dominantFrequency: Double? = nil, energy: Double? = nil,
         spectralCentroid: Double? = nil, tags: [String] = []) {
        self.dominantFrequency = dominantFrequency
        self.energy = energy
        self.spectralCentroid = spectralCentroid
        self.tags = tags
    }
}

// MARK: - Persistence

extension BurstAnalysis {
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    static func load(from url: URL) throws -> BurstAnalysis {
        let data = try Data(contentsOf: url)
        return try decoder.decode(BurstAnalysis.self, from: data)
    }

    func toJSONData() throws -> Data {
        try BurstAnalysis.encoder.encode(self)
    }
}

// MARK: - Sample data for previews

extension BurstAnalysis {
    static var sample: BurstAnalysis {
        BurstAnalysis(
            source: "rec_1742300000.wav",
            duration: 12.0,
            sampleRate: 44100,
            chunks: [
                BurstChunk(startTime: 0.10, endTime: 0.55, label: "kick",
                           characteristics: ChunkCharacteristics(dominantFrequency: 80, energy: 0.90,
                                                                 tags: ["low", "transient"])),
                BurstChunk(startTime: 0.90, endTime: 1.15, label: "snare",
                           characteristics: ChunkCharacteristics(dominantFrequency: 200, energy: 0.75,
                                                                 tags: ["mid", "transient"])),
                BurstChunk(startTime: 1.60, endTime: 1.80, label: "",
                           characteristics: ChunkCharacteristics(dominantFrequency: 3200, energy: 0.40,
                                                                 tags: ["hi-hat"])),
                BurstChunk(startTime: 2.40, endTime: 2.95, label: "kick",
                           characteristics: ChunkCharacteristics(dominantFrequency: 80, energy: 0.88,
                                                                 tags: ["low", "transient"])),
            ]
        )
    }
}
