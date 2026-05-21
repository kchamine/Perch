import Foundation

protocol FavoritesRepository {
    func loadFavorites() async throws -> Set<UUID>
    func addFavorite(spotID: UUID) async throws
    func removeFavorites(ids: Set<UUID>) async throws
}

final class LocalFavoritesRepository: FavoritesRepository {
    private let defaults: UserDefaults
    private let key = "favoriteSpotIDs"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadFavorites() async throws -> Set<UUID> {
        let values = defaults.array(forKey: key) as? [String] ?? []
        return Set(values.compactMap(UUID.init(uuidString:)))
    }

    func addFavorite(spotID: UUID) async throws {
        var ids = try await loadFavorites()
        ids.insert(spotID)
        persist(ids)
    }

    func removeFavorites(ids: Set<UUID>) async throws {
        var existing = try await loadFavorites()
        existing.subtract(ids)
        persist(existing)
    }

    private func persist(_ ids: Set<UUID>) {
        defaults.set(ids.map(\.uuidString), forKey: key)
    }
}
