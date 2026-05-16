import CoreLocation
import Foundation

@MainActor
final class SpotStore: ObservableObject {
    @Published private(set) var seededSpots: [Spot] = []
    @Published private(set) var userSpots: [Spot] = []
    @Published var filters: SpotFilterState {
        didSet { persistFilters() }
    }
    @Published var selectedSpot: Spot?
    @Published private(set) var loadError: String?

    private let repository: SpotRepository
    private let defaults: UserDefaults
    private let filtersKey = "perch.filters"

    init(repository: SpotRepository = LocalSpotRepository(), defaults: UserDefaults = .standard) {
        self.repository = repository
        self.defaults = defaults
        if let data = defaults.data(forKey: filtersKey),
           let savedFilters = try? JSONDecoder().decode(SpotFilterState.self, from: data) {
            self.filters = savedFilters
        } else {
            self.filters = SpotFilterState()
        }
    }

    var allSpots: [Spot] {
        (seededSpots + userSpots).sorted { $0.name < $1.name }
    }

    func load() {
        do {
            seededSpots = try repository.loadSeededSpots()
            userSpots = try repository.loadUserSpots()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    func addSpot(_ spot: Spot) {
        userSpots.append(spot)
        persistUserSpots()
    }

    func update(_ spot: Spot) {
        guard let index = userSpots.firstIndex(where: { $0.id == spot.id }) else { return }
        userSpots[index] = spot
        if selectedSpot?.id == spot.id {
            selectedSpot = spot
        }
        persistUserSpots()
    }

    func deleteUserSpots(ids: Set<UUID>) {
        userSpots.removeAll { ids.contains($0.id) }
        if selectedSpot.map({ ids.contains($0.id) }) == true {
            selectedSpot = nil
        }
        persistUserSpots()
    }

    func isUserSpot(_ spot: Spot) -> Bool {
        userSpots.contains(where: { $0.id == spot.id })
    }

    func filteredSpots(location: CLLocation?, favorites: Set<UUID>) -> [Spot] {
        let radiusMeters = 3_500.0
        return allSpots.filter { spot in
            if filters.favoritesOnly && !favorites.contains(spot.id) { return false }
            if filters.quietOnly && spot.noiseLevel != .quiet { return false }
            if filters.shadedOnly && spot.shadeLevel == .sunny { return false }
            if filters.sunsetOnly && spot.bestTime != .sunset && spot.bestTime != .evening { return false }
            if filters.accessibleOnly && ![AccessibilityLevel.wheelchairFriendly, .stepFree].contains(spot.accessibility) { return false }
            if filters.easyAccessOnly && spot.accessEffort != .easy { return false }
            if filters.nearbyOnly, let location {
                let distance = CLLocation(latitude: spot.latitude, longitude: spot.longitude).distance(from: location)
                if distance > radiusMeters { return false }
            }
            return true
        }
        .sorted { lhs, rhs in
            guard let location else { return lhs.name < rhs.name }
            return lhs.distance(from: location) < rhs.distance(from: location)
        }
    }

    private func persistUserSpots() {
        do {
            try repository.saveUserSpots(userSpots)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func persistFilters() {
        do {
            defaults.set(try JSONEncoder().encode(filters), forKey: filtersKey)
        } catch {
            loadError = error.localizedDescription
        }
    }
}

extension Spot {
    func distance(from location: CLLocation?) -> CLLocationDistance {
        guard let location else { return .infinity }
        return CLLocation(latitude: latitude, longitude: longitude).distance(from: location)
    }
}
