import Foundation

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var favoriteIDs: Set<UUID> = []
    @Published private(set) var loadError: String?

    private let repository: FavoritesRepository

    init(repository: FavoritesRepository = LocalFavoritesRepository()) {
        self.repository = repository
    }

    func isFavorite(_ spot: Spot) -> Bool {
        favoriteIDs.contains(spot.id)
    }

    func toggle(_ spot: Spot) {
        if favoriteIDs.contains(spot.id) {
            favoriteIDs.remove(spot.id)
            Task { await persistRemove(ids: [spot.id], rollback: { self.favoriteIDs.insert(spot.id) }) }
        } else {
            favoriteIDs.insert(spot.id)
            Task { await persistAdd(spotID: spot.id, rollback: { self.favoriteIDs.remove(spot.id) }) }
        }
    }

    func remove(_ ids: Set<UUID>) {
        let removed = favoriteIDs.intersection(ids)
        favoriteIDs.subtract(ids)
        Task { await persistRemove(ids: ids, rollback: { self.favoriteIDs.formUnion(removed) }) }
    }

    func load() async {
        do {
            favoriteIDs = try await repository.loadFavorites()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    func clear() {
        favoriteIDs = []
        loadError = nil
    }

    private func persistAdd(spotID: UUID, rollback: @escaping @MainActor () -> Void) async {
        do {
            try await repository.addFavorite(spotID: spotID)
            loadError = nil
        } catch {
            rollback()
            loadError = error.localizedDescription
        }
    }

    private func persistRemove(ids: Set<UUID>, rollback: @escaping @MainActor () -> Void) async {
        do {
            try await repository.removeFavorites(ids: ids)
            loadError = nil
        } catch {
            rollback()
            loadError = error.localizedDescription
        }
    }
}
