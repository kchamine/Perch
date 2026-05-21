import XCTest
import CoreLocation
@testable import PerchIOS

// MARK: - Stub Repository

final class StubSpotRepository: SpotRepository {
    var seededSpots: [Spot] = []
    var userSpots: [Spot] = []
    var savedUserSpots: [Spot]?

    func loadSeededSpots() throws -> [Spot] { seededSpots }
    func loadUserSpots() throws -> [Spot] { userSpots }
    func saveUserSpots(_ spots: [Spot]) throws { savedUserSpots = spots }
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

    func testLoadSeededSpots() {
        let spot = makeSpot(name: "Seeded")
        repository.seededSpots = [spot]
        store.load()
        XCTAssertEqual(store.seededSpots.count, 1)
        XCTAssertEqual(store.seededSpots[0].name, "Seeded")
    }

    func testLoadUserSpots() {
        let spot = makeSpot(name: "User Spot")
        repository.userSpots = [spot]
        store.load()
        XCTAssertEqual(store.userSpots.count, 1)
        XCTAssertEqual(store.userSpots[0].name, "User Spot")
    }

    func testAllSpotsCombinesSeededAndUser() {
        repository.seededSpots = [makeSpot(name: "Seeded")]
        repository.userSpots = [makeSpot(name: "User")]
        store.load()
        XCTAssertEqual(store.allSpots.count, 2)
    }

    // MARK: Add / Delete / Update

    func testAddSpot() {
        let spot = makeSpot(name: "New Spot")
        store.addSpot(spot)
        XCTAssertEqual(store.userSpots.count, 1)
        XCTAssertEqual(store.userSpots[0].name, "New Spot")
        XCTAssertEqual(repository.savedUserSpots?.count, 1)
    }

    func testDeleteUserSpot() {
        let spot = makeSpot()
        store.addSpot(spot)
        store.deleteUserSpots(ids: [spot.id])
        XCTAssertTrue(store.userSpots.isEmpty)
        XCTAssertEqual(repository.savedUserSpots?.count, 0)
    }

    func testUpdateUserSpot() {
        let spot = makeSpot(name: "Original")
        store.addSpot(spot)
        var updated = spot
        updated.name = "Updated"
        store.update(updated)
        XCTAssertEqual(store.userSpots[0].name, "Updated")
    }

    func testUpdateSelectedSpotFollowsUpdate() {
        let spot = makeSpot(name: "Selected")
        store.addSpot(spot)
        store.selectedSpot = spot
        var updated = spot
        updated.name = "Updated Selected"
        store.update(updated)
        XCTAssertEqual(store.selectedSpot?.name, "Updated Selected")
    }

    func testIsUserSpot() {
        let spot = makeSpot()
        store.addSpot(spot)
        XCTAssertTrue(store.isUserSpot(spot))
        let seeded = makeSpot()
        repository.seededSpots = [seeded]
        store.load()
        XCTAssertFalse(store.isUserSpot(seeded))
    }

    // MARK: filteredSpots — privacy

    func testPrivateSpotsExcludedFromFilteredSpots() {
        let publicSpot = makeSpot(name: "Public", isPrivate: false)
        let privateSpot = makeSpot(name: "Private", isPrivate: true)
        repository.seededSpots = [publicSpot, privateSpot]
        store.load()
        let results = store.filteredSpots(location: nil, favorites: [])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Public")
    }

    func testPublicSpotsRetainedInFilteredSpots() {
        let spot = makeSpot(name: "Public", isPrivate: false)
        repository.seededSpots = [spot]
        store.load()
        let results = store.filteredSpots(location: nil, favorites: [])
        XCTAssertEqual(results.count, 1)
    }

    // MARK: filteredSpots — filter toggles

    func testQuietOnlyFilter() {
        let quiet = makeSpot(name: "Quiet", noiseLevel: .quiet)
        let loud = makeSpot(name: "Loud", noiseLevel: .lively)
        repository.seededSpots = [quiet, loud]
        store.load()
        store.filters.quietOnly = true
        let results = store.filteredSpots(location: nil, favorites: [])
        XCTAssertTrue(results.allSatisfy { $0.noiseLevel == .quiet })
    }

    func testShadedOnlyFilter() {
        let shaded = makeSpot(name: "Shaded", shadeLevel: .shaded)
        let sunny = makeSpot(name: "Sunny", shadeLevel: .sunny)
        repository.seededSpots = [shaded, sunny]
        store.load()
        store.filters.shadedOnly = true
        let results = store.filteredSpots(location: nil, favorites: [])
        XCTAssertTrue(results.allSatisfy { $0.shadeLevel != .sunny })
    }

    func testSunsetOnlyFilter() {
        let sunsetSpot = makeSpot(name: "Sunset", bestTime: .sunset)
        let morningSpot = makeSpot(name: "Morning", bestTime: .morning)
        repository.seededSpots = [sunsetSpot, morningSpot]
        store.load()
        store.filters.sunsetOnly = true
        let results = store.filteredSpots(location: nil, favorites: [])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Sunset")
    }

    func testAccessibleOnlyFilter() {
        let accessible = makeSpot(name: "Accessible", accessibility: .wheelchairFriendly)
        let limited = makeSpot(name: "Limited", accessibility: .limited)
        repository.seededSpots = [accessible, limited]
        store.load()
        store.filters.accessibleOnly = true
        let results = store.filteredSpots(location: nil, favorites: [])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Accessible")
    }

    func testEasyAccessOnlyFilter() {
        let easy = makeSpot(name: "Easy", accessEffort: .easy)
        let moderate = makeSpot(name: "Moderate", accessEffort: .moderate)
        repository.seededSpots = [easy, moderate]
        store.load()
        store.filters.easyAccessOnly = true
        let results = store.filteredSpots(location: nil, favorites: [])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Easy")
    }

    func testFavoritesOnlyFilter() {
        let fav = makeSpot(name: "Fav")
        let notFav = makeSpot(name: "NotFav")
        repository.seededSpots = [fav, notFav]
        store.load()
        store.filters.favoritesOnly = true
        let results = store.filteredSpots(location: nil, favorites: [fav.id])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Fav")
    }

    func testNearbyOnlyFilterExcludesFarSpots() {
        // Spot at SF (37.7749, -122.4194) — base location
        // Spot at NYC (40.7128, -74.0060) — far away
        let nearby = makeSpot(name: "Nearby", latitude: 37.7750, longitude: -122.4195)
        let far = makeSpot(name: "Far", latitude: 40.7128, longitude: -74.0060)
        repository.seededSpots = [nearby, far]
        store.load()
        store.filters.nearbyOnly = true
        let sfLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let results = store.filteredSpots(location: sfLocation, favorites: [])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Nearby")
    }

    // MARK: Sort

    func testSortByNameWhenNoLocation() {
        let b = makeSpot(name: "B Spot")
        let a = makeSpot(name: "A Spot")
        repository.seededSpots = [b, a]
        store.load()
        let results = store.filteredSpots(location: nil, favorites: [])
        XCTAssertEqual(results[0].name, "A Spot")
        XCTAssertEqual(results[1].name, "B Spot")
    }

    func testSortByDistanceWhenLocationProvided() {
        let close = makeSpot(name: "Close", latitude: 37.7750, longitude: -122.4195)
        let far = makeSpot(name: "Far", latitude: 37.8000, longitude: -122.4100)
        repository.seededSpots = [far, close]
        store.load()
        let sfLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let results = store.filteredSpots(location: sfLocation, favorites: [])
        XCTAssertEqual(results[0].name, "Close")
    }

    // MARK: isPrivate round-trip

    func testIsPrivateCodableRoundTrip() throws {
        let spot = makeSpot(isPrivate: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(spot)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Spot.self, from: data)
        XCTAssertTrue(decoded.isPrivate)
    }

    func testIsPrivateDefaultsFalseWhenMissingFromJSON() throws {
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
