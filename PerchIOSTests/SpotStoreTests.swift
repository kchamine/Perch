import XCTest
import CoreLocation
@testable import PerchIOS

// MARK: - Stub Repository

final class StubSpotRepository: SpotRepository {
    var seededSpots: [Spot] = []
    var userSpots: [Spot] = []
    var addedSpots: [Spot] = []
    var updatedSpots: [Spot] = []
    var deletedSpotIDs: Set<UUID> = []

    func loadSeededSpots() async throws -> [Spot] { seededSpots }
    func loadUserSpots() async throws -> [Spot] { userSpots }

    func addUserSpot(_ spot: Spot) async throws {
        addedSpots.append(spot)
        userSpots.append(spot)
    }

    func updateUserSpot(_ spot: Spot) async throws {
        updatedSpots.append(spot)
        if let index = userSpots.firstIndex(where: { $0.id == spot.id }) {
            userSpots[index] = spot
        }
    }

    func deleteUserSpots(ids: Set<UUID>) async throws {
        deletedSpotIDs.formUnion(ids)
        userSpots.removeAll { ids.contains($0.id) }
    }
}

// MARK: - Helpers

private func makeSpot(
    id: UUID = UUID(),
    name: String = "Test Spot",
    noiseLevel: NoiseLevel = .quiet,
    shadeLevel: ShadeLevel = .partial,
    bestTime: BestTime = .afternoon,
    accessibility: AccessibilityLevel = .stepFree,
    accessEffort: AccessEffort = .easy,
    viewType: ViewType = .park,
    isPrivate: Bool = false,
    latitude: Double = 37.7749,
    longitude: Double = -122.4194
) -> Spot {
    Spot(
        id: id,
        name: name,
        subtitle: "Subtitle",
        latitude: latitude,
        longitude: longitude,
        photoName: nil,
        photoURL: nil,
        spotType: .bench,
        seatingType: .bench,
        hasSeating: true,
        shadeLevel: shadeLevel,
        noiseLevel: noiseLevel,
        crowdLevel: .low,
        viewType: viewType,
        bestTime: bestTime,
        accessibility: accessibility,
        accessEffort: accessEffort,
        comfortRating: 4,
        scenicRating: 4,
        publicAccessConfirmed: true,
        isPrivate: isPrivate,
        notes: "",
        lastConfirmed: .now
    )
}

// MARK: - Tests

@MainActor
final class SpotStoreTests: XCTestCase {
    private var store: SpotStore!
    private var repository: StubSpotRepository!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        repository = StubSpotRepository()
        defaults = UserDefaults(suiteName: "com.perch.tests.\(UUID().uuidString)")!
        store = SpotStore(repository: repository, defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: defaults.persistentDomain(forName: "com.perch.tests")?.description ?? "")
        store = nil
        repository = nil
        defaults = nil
    }

    // MARK: Load

    func testLoadSeededSpots() async {
        let spot = makeSpot(name: "Seeded")
        repository.seededSpots = [spot]
        await store.load()
        XCTAssertEqual(store.seededSpots.count, 1)
        XCTAssertEqual(store.seededSpots[0].name, "Seeded")
    }

    func testLoadUserSpots() async {
        let spot = makeSpot(name: "User Spot")
        repository.userSpots = [spot]
        await store.load()
        XCTAssertEqual(store.userSpots.count, 1)
        XCTAssertEqual(store.userSpots[0].name, "User Spot")
    }

    func testAllSpotsCombinesSeededAndUser() async {
        repository.seededSpots = [makeSpot(name: "Seeded")]
        repository.userSpots = [makeSpot(name: "User")]
        await store.load()
        XCTAssertEqual(store.allSpots.count, 2)
    }

    // MARK: Add / Delete / Update

    func testAddSpot() async {
        let spot = makeSpot(name: "New Spot")
        await store.addSpot(spot)
        XCTAssertEqual(store.userSpots.count, 1)
        XCTAssertEqual(store.userSpots[0].name, "New Spot")
        XCTAssertEqual(repository.addedSpots.map(\.id), [spot.id])
    }

    func testDeleteUserSpot() async {
        let spot = makeSpot()
        await store.addSpot(spot)
        await store.deleteUserSpots(ids: [spot.id])
        XCTAssertTrue(store.userSpots.isEmpty)
        XCTAssertEqual(repository.deletedSpotIDs, [spot.id])
    }

    func testUpdateUserSpot() async {
        let spot = makeSpot(name: "Original")
        await store.addSpot(spot)
        var updated = spot
        updated.name = "Updated"
        await store.update(updated)
        XCTAssertEqual(store.userSpots[0].name, "Updated")
        XCTAssertEqual(repository.updatedSpots.map(\.id), [spot.id])
    }

    func testUpdateSelectedSpotFollowsUpdate() async {
        let spot = makeSpot(name: "Selected")
        await store.addSpot(spot)
        store.selectedSpot = spot
        var updated = spot
        updated.name = "Updated Selected"
        await store.update(updated)
        XCTAssertEqual(store.selectedSpot?.name, "Updated Selected")
    }

    func testIsUserSpot() async {
        let spot = makeSpot()
        await store.addSpot(spot)
        XCTAssertTrue(store.isUserSpot(spot))
        let seeded = makeSpot()
        repository.seededSpots = [seeded]
        await store.load()
        XCTAssertFalse(store.isUserSpot(seeded))
    }

    // MARK: filteredSpots — privacy

    func testPrivateSpotsExcludedFromFilteredSpots() async {
        let publicSpot = makeSpot(name: "Public", isPrivate: false)
        let privateSpot = makeSpot(name: "Private", isPrivate: true)
        repository.seededSpots = [publicSpot, privateSpot]
        await store.load()
        let results = store.filteredSpots(location: nil, favorites: [])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Public")
    }

    func testPublicSpotsRetainedInFilteredSpots() async {
        let spot = makeSpot(name: "Public", isPrivate: false)
        repository.seededSpots = [spot]
        await store.load()
        let results = store.filteredSpots(location: nil, favorites: [])
        XCTAssertEqual(results.count, 1)
    }

    // MARK: filteredSpots — filter toggles

    func testQuietOnlyFilter() async {
        let quiet = makeSpot(name: "Quiet", noiseLevel: .quiet)
        let loud = makeSpot(name: "Loud", noiseLevel: .lively)
        repository.seededSpots = [quiet, loud]
        await store.load()
        store.filters.quietOnly = true
        let results = store.filteredSpots(location: nil, favorites: [])
        XCTAssertTrue(results.allSatisfy { $0.noiseLevel == .quiet })
    }

    func testShadedOnlyFilter() async {
        let shaded = makeSpot(name: "Shaded", shadeLevel: .shaded)
        let sunny = makeSpot(name: "Sunny", shadeLevel: .sunny)
        repository.seededSpots = [shaded, sunny]
        await store.load()
        store.filters.shadedOnly = true
        let results = store.filteredSpots(location: nil, favorites: [])
        XCTAssertTrue(results.allSatisfy { $0.shadeLevel != .sunny })
    }

    func testSunsetOnlyFilter() async {
        let sunsetSpot = makeSpot(name: "Sunset", bestTime: .sunset)
        let morningSpot = makeSpot(name: "Morning", bestTime: .morning)
        repository.seededSpots = [sunsetSpot, morningSpot]
        await store.load()
        store.filters.sunsetOnly = true
        let results = store.filteredSpots(location: nil, favorites: [])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Sunset")
    }

    func testAccessibleOnlyFilter() async {
        let accessible = makeSpot(name: "Accessible", accessibility: .wheelchairFriendly)
        let limited = makeSpot(name: "Limited", accessibility: .limited)
        repository.seededSpots = [accessible, limited]
        await store.load()
        store.filters.accessibleOnly = true
        let results = store.filteredSpots(location: nil, favorites: [])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Accessible")
    }

    func testEasyAccessOnlyFilter() async {
        let easy = makeSpot(name: "Easy", accessEffort: .easy)
        let moderate = makeSpot(name: "Moderate", accessEffort: .moderate)
        repository.seededSpots = [easy, moderate]
        await store.load()
        store.filters.easyAccessOnly = true
        let results = store.filteredSpots(location: nil, favorites: [])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Easy")
    }

    func testFavoritesOnlyFilter() async {
        let fav = makeSpot(name: "Fav")
        let notFav = makeSpot(name: "NotFav")
        repository.seededSpots = [fav, notFav]
        await store.load()
        store.filters.favoritesOnly = true
        let results = store.filteredSpots(location: nil, favorites: [fav.id])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Fav")
    }

    func testNearbyOnlyFilterExcludesFarSpots() async {
        // Spot at SF (37.7749, -122.4194) — base location
        // Spot at NYC (40.7128, -74.0060) — far away
        let nearby = makeSpot(name: "Nearby", latitude: 37.7750, longitude: -122.4195)
        let far = makeSpot(name: "Far", latitude: 40.7128, longitude: -74.0060)
        repository.seededSpots = [nearby, far]
        await store.load()
        store.filters.nearbyOnly = true
        let sfLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let results = store.filteredSpots(location: sfLocation, favorites: [])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Nearby")
    }

    // MARK: Sort

    func testSortByNameWhenNoLocation() async {
        let b = makeSpot(name: "B Spot")
        let a = makeSpot(name: "A Spot")
        repository.seededSpots = [b, a]
        await store.load()
        let results = store.filteredSpots(location: nil, favorites: [])
        XCTAssertEqual(results[0].name, "A Spot")
        XCTAssertEqual(results[1].name, "B Spot")
    }

    func testSortByDistanceWhenLocationProvided() async {
        let close = makeSpot(name: "Close", latitude: 37.7750, longitude: -122.4195)
        let far = makeSpot(name: "Far", latitude: 37.8000, longitude: -122.4100)
        repository.seededSpots = [far, close]
        await store.load()
        let sfLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let results = store.filteredSpots(location: sfLocation, favorites: [])
        XCTAssertEqual(results[0].name, "Close")
    }

    // MARK: isPrivate round-trip

    func testIsPrivateCodableRoundTrip() async throws {
        let spot = makeSpot(isPrivate: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(spot)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Spot.self, from: data)
        XCTAssertTrue(decoded.isPrivate)
    }

    func testIsPrivateDefaultsFalseWhenMissingFromJSON() async throws {
        // JSON without isPrivate field
        let json = """
        {
            "id": "4F779478-D1D4-4F17-A7A1-4B0F5B6E71A1",
            "name": "Test",
            "subtitle": "Sub",
            "latitude": 37.8,
            "longitude": -122.4,
            "photoName": null,
            "userPhotoPath": null,
            "spotType": "bench",
            "seatingType": "bench",
            "hasSeating": true,
            "shadeLevel": "sunny",
            "noiseLevel": "quiet",
            "crowdLevel": "low",
            "viewType": "park",
            "bestTime": "afternoon",
            "accessibility": "stepFree",
            "accessEffort": "easy",
            "comfortRating": 4,
            "scenicRating": 4,
            "publicAccessConfirmed": true,
            "notes": "",
            "lastConfirmed": "2026-03-10T18:00:00Z"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let spot = try decoder.decode(Spot.self, from: json)
        XCTAssertFalse(spot.isPrivate)
    }
}
