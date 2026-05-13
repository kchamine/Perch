import Foundation

final class LocalSpotRepository: SpotRepository {
    private let fileManager: FileManager
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadSeededSpots() throws -> [Spot] {
        guard let url = Bundle.main.url(forResource: "SeededSpots", withExtension: "json") else {
            throw SpotRepositoryError.seedDataMissing
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode([Spot].self, from: data)
    }

    func loadUserSpots() throws -> [Spot] {
        let url = try userSpotsURL()
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try decoder.decode([Spot].self, from: data)
    }

    func saveUserSpots(_ spots: [Spot]) throws {
        let url = try userSpotsURL()
        let data = try encoder.encode(spots)
        try data.write(to: url, options: .atomic)
    }

    private func userSpotsURL() throws -> URL {
        let directory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return directory.appendingPathComponent("user-spots.json")
    }
}

enum SpotRepositoryError: Error, LocalizedError {
    case seedDataMissing

    var errorDescription: String? {
        switch self {
        case .seedDataMissing:
            "Seeded spot data is missing from the app bundle."
        }
    }
}
