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

    func load() async {
        do {
            seededSpots = try await repository.loadSeededSpots()
            userSpots = try await repository.loadUserSpots()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    func addSpot(_ spot: Spot) async {
        userSpots.append(spot)
        do {
            try await repository.addUserSpot(spot)
            loadError = nil
        } catch {
            userSpots.removeAll { $0.id == spot.id }
            loadError = error.localizedDescription
        }
    }

    func update(_ spot: Spot) async {
        guard let index = userSpots.firstIndex(where: { $0.id == spot.id }) else { return }
        let previousSpot = userSpots[index]
        let previousSelectedSpot = selectedSpot
        userSpots[index] = spot
        if selectedSpot?.id == spot.id {
            selectedSpot = spot
        }
        do {
            try await repository.updateUserSpot(spot)
            loadError = nil
        } catch {
            userSpots[index] = previousSpot
            selectedSpot = previousSelectedSpot
            loadError = error.localizedDescription
        }
    }

    func deleteUserSpots(ids: Set<UUID>) async {
        let previousUserSpots = userSpots
        let previousSelectedSpot = selectedSpot
        userSpots.removeAll { ids.contains($0.id) }
        if selectedSpot.map({ ids.contains($0.id) }) == true {
            selectedSpot = nil
        }
        do {
            try await repository.deleteUserSpots(ids: ids)
            loadError = nil
        } catch {
            userSpots = previousUserSpots
            selectedSpot = previousSelectedSpot
            loadError = error.localizedDescription
        }
    }

    func isUserSpot(_ spot: Spot) -> Bool {
        userSpots.contains(where: { $0.id == spot.id })
    }

    func filteredSpots(location: CLLocation?, favorites: Set<UUID>) -> [Spot] {
        let radiusMeters = 3_500.0
        return allSpots.filter { spot in
            if spot.isPrivate { return false }
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

    func clearUserSpots() {
        let currentUserSpotIDs = Set(userSpots.map(\.id))
        userSpots = []
        if selectedSpot.map({ currentUserSpotIDs.contains($0.id) }) == true {
            selectedSpot = nil
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
