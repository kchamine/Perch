import XCTest
@testable import PerchIOS

final class FavoritesStoreTests: XCTestCase {
    private var store: FavoritesStore!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "com.perch.favtests.\(UUID().uuidString)")!
        store = FavoritesStore(defaults: defaults)
    }

    override func tearDown() {
        store = nil
        defaults = nil
        super.tearDown()
    }

    private func makeSpot(id: UUID = UUID()) -> Spot {
        Spot(
            id: id,
            name: "Test",
            subtitle: "Sub",
            latitude: 37.7,
            longitude: -122.4,
            photoName: nil,
            photoURL: nil,
            spotType: .bench,
            seatingType: .bench,
            hasSeating: true,
            shadeLevel: .partial,
            noiseLevel: .quiet,
            crowdLevel: .low,
            viewType: .park,
            bestTime: .afternoon,
            accessibility: .stepFree,
            accessEffort: .easy,
            comfortRating: 4,
            scenicRating: 4,
            publicAccessConfirmed: true,
            isPrivate: false,
            notes: "",
            lastConfirmed: .now
        )
    }

    // MARK: - Toggle

    func testToggleAddsFavorite() {
        let spot = makeSpot()
        XCTAssertFalse(store.isFavorite(spot))
        store.toggle(spot)
        XCTAssertTrue(store.isFavorite(spot))
    }

    func testToggleRemovesFavorite() {
        let spot = makeSpot()
        store.toggle(spot)
        store.toggle(spot)
        XCTAssertFalse(store.isFavorite(spot))
    }

    func testToggleIsIdempotentAfterTwoToggles() {
        let spot = makeSpot()
        store.toggle(spot)
        store.toggle(spot)
        store.toggle(spot)
        XCTAssertTrue(store.isFavorite(spot))
    }

    // MARK: - Remove

    func testRemove() {
        let spot = makeSpot()
        store.toggle(spot)
        store.remove([spot.id])
        XCTAssertFalse(store.isFavorite(spot))
    }

    func testRemoveMultiple() {
        let a = makeSpot()
        let b = makeSpot()
        let c = makeSpot()
        store.toggle(a)
        store.toggle(b)
        store.toggle(c)
        store.remove([a.id, b.id])
        XCTAssertFalse(store.isFavorite(a))
        XCTAssertFalse(store.isFavorite(b))
        XCTAssertTrue(store.isFavorite(c))
    }

    // MARK: - Persistence

    func testPersistenceRoundTrip() {
        let spot = makeSpot()
        store.toggle(spot)

        // Create a new store from the same defaults — should load the persisted value
        let store2 = FavoritesStore(defaults: defaults)
        XCTAssertTrue(store2.isFavorite(spot))
    }

    func testPersistenceAfterRemove() {
        let spot = makeSpot()
        store.toggle(spot)
        store.toggle(spot) // remove it

        let store2 = FavoritesStore(defaults: defaults)
        XCTAssertFalse(store2.isFavorite(spot))
    }

    func testEmptyFavoritesOnFreshStart() {
        XCTAssertTrue(store.favoriteIDs.isEmpty)
    }
}
