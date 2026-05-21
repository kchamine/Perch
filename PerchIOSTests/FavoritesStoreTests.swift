import XCTest
@testable import PerchIOS

@MainActor
final class FavoritesStoreTests: XCTestCase {
    private var store: FavoritesStore!
    private var repository: StubFavoritesRepository!

    override func setUp() async throws {
        repository = StubFavoritesRepository()
        store = FavoritesStore(repository: repository)
    }

    override func tearDown() async throws {
        store = nil
        repository = nil
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

    func testLoadUsesRepositoryFavorites() async {
        let id = UUID()
        repository.loadedFavorites = [id]

        await store.load()

        XCTAssertEqual(store.favoriteIDs, [id])
        XCTAssertNil(store.loadError)
    }

    func testToggleAddsFavoriteOptimisticallyAndPersists() async {
        let spot = makeSpot()

        store.toggle(spot)
        await settleAsyncStoreWork()

        XCTAssertTrue(store.isFavorite(spot))
        XCTAssertEqual(repository.addedSpotIDs, [spot.id])
    }

    func testToggleRemovesFavoriteOptimisticallyAndPersists() async {
        let spot = makeSpot()
        store.toggle(spot)
        await settleAsyncStoreWork()

        store.toggle(spot)
        await settleAsyncStoreWork()

        XCTAssertFalse(store.isFavorite(spot))
        XCTAssertEqual(repository.removedIDs, [spot.id])
    }

    func testRemoveRollsBackWhenRepositoryFails() async {
        let spot = makeSpot()
        store.toggle(spot)
        await settleAsyncStoreWork()
        repository.removeError = TestRepositoryError.failed

        store.remove([spot.id])
        await settleAsyncStoreWork()

        XCTAssertTrue(store.isFavorite(spot))
        XCTAssertEqual(store.loadError, TestRepositoryError.failed.localizedDescription)
    }

    func testLocalFavoritesRepositoryPersistsRoundTrip() async throws {
        let defaults = UserDefaults(suiteName: "com.perch.favtests.(UUID().uuidString)")!
        let spotID = UUID()
        let repository = LocalFavoritesRepository(defaults: defaults)

        try await repository.addFavorite(spotID: spotID)

        let restored = try await LocalFavoritesRepository(defaults: defaults).loadFavorites()
        XCTAssertEqual(restored, [spotID])
    }
}

final class StubFavoritesRepository: FavoritesRepository {
    var loadedFavorites: Set<UUID> = []
    var loadError: Error?
    var addError: Error?
    var removeError: Error?
    var addedSpotIDs: [UUID] = []
    var removedIDs: Set<UUID> = []

    func loadFavorites() async throws -> Set<UUID> {
        if let loadError { throw loadError }
        return loadedFavorites
    }

    func addFavorite(spotID: UUID) async throws {
        if let addError { throw addError }
        addedSpotIDs.append(spotID)
        loadedFavorites.insert(spotID)
    }

    func removeFavorites(ids: Set<UUID>) async throws {
        if let removeError { throw removeError }
        removedIDs.formUnion(ids)
        loadedFavorites.subtract(ids)
    }
}

enum TestRepositoryError: LocalizedError, Equatable {
    case failed

    var errorDescription: String? {
        "Repository failed"
    }
}

func settleAsyncStoreWork() async {
    try? await Task.sleep(nanoseconds: 50_000_000)
}
