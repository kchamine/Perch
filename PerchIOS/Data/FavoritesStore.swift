import Foundation

final class FavoritesStore: ObservableObject {
    @Published private(set) var favoriteIDs: Set<UUID>
    private let defaults: UserDefaults
    private let key = "favoriteSpotIDs"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let values = defaults.array(forKey: key) as? [String] ?? []
        self.favoriteIDs = Set(values.compactMap(UUID.init(uuidString:)))
    }

    func isFavorite(_ spot: Spot) -> Bool {
        favoriteIDs.contains(spot.id)
    }

    func toggle(_ spot: Spot) {
        if favoriteIDs.contains(spot.id) {
            favoriteIDs.remove(spot.id)
        } else {
            favoriteIDs.insert(spot.id)
        }
        persist()
    }

    func remove(_ ids: Set<UUID>) {
        favoriteIDs.subtract(ids)
        persist()
    }

    private func persist() {
        defaults.set(favoriteIDs.map(\.uuidString), forKey: key)
    }
}
