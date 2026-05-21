import XCTest
@testable import PerchIOS

final class LocalDataMigrationTests: XCTestCase {
    private let userID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    private var localSpotRepository: LocalSpotRepository!
    private var localReviewRepository: LocalReviewRepository!
    private var localFavoritesRepository: LocalFavoritesRepository!
    private var localProfileRepository: LocalProfileRepository!
    private var checkpointStore: LocalMigrationCheckpointStore!
    private var defaults: UserDefaults!
    private var temporaryDirectory: URL!
    private var localSpotIDs: Set<UUID> = []

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "com.perch.migrationtests.\(UUID().uuidString)")!
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("perch-migrationtests-\(UUID().uuidString)", isDirectory: true)
        localSpotRepository = LocalSpotRepository(documentsDirectory: temporaryDirectory)
        localReviewRepository = LocalReviewRepository(defaults: defaults)
        localFavoritesRepository = LocalFavoritesRepository(defaults: defaults)
        localProfileRepository = LocalProfileRepository(defaults: defaults)
        checkpointStore = LocalMigrationCheckpointStore(defaults: defaults)
    }

    override func tearDown() async throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        defaults = nil
        temporaryDirectory = nil
        localSpotRepository = nil
        localReviewRepository = nil
        localFavoritesRepository = nil
        localProfileRepository = nil
        checkpointStore = nil
        localSpotIDs = []
    }

    func testSummaryDetectsLocalData() async throws {
        let spot = makeMigrationSpot()
        try await localSpotRepository.addUserSpot(spot)
        localSpotIDs.insert(spot.id)
        try await localReviewRepository.insert(makeReview(spotID: spot.id))
        try await localFavoritesRepository.addFavorite(spotID: spot.id)
        try await localProfileRepository.saveProfile(.default)

        let migrator = makeMigrator()

        let summary = try await migrator.localSummary()

        XCTAssertEqual(summary.spotCount, 1)
        XCTAssertEqual(summary.reviewCount, 1)
        XCTAssertEqual(summary.favoriteCount, 1)
        XCTAssertTrue(summary.hasProfile)
        XCTAssertTrue(summary.hasData)
    }

    func testMigrationUploadsLocalDataAndMarksAccountComplete() async throws {
        let spot = makeMigrationSpot()
        let review = makeReview(spotID: spot.id)
        var profile = UserProfile.default
        profile.displayName = "Migrated User"
        try await localSpotRepository.addUserSpot(spot)
        localSpotIDs.insert(spot.id)
        try await localReviewRepository.insert(review)
        try await localFavoritesRepository.addFavorite(spotID: spot.id)
        try await localProfileRepository.saveProfile(profile)

        let remoteSpots = StubSpotRepository()
        let remoteReviews = StubReviewRepository()
        let remoteFavorites = StubFavoritesRepository()
        let remoteProfile = StubProfileRepository()
        let migrator = makeMigrator(
            remoteSpotRepository: remoteSpots,
            remoteReviewRepository: remoteReviews,
            remoteFavoritesRepository: remoteFavorites,
            remoteProfileRepository: remoteProfile
        )

        let result = try await migrator.migrate(userID: userID) { _ in }

        XCTAssertTrue(result.didComplete)
        XCTAssertEqual(remoteSpots.addedSpots.map(\.id), [spot.id])
        XCTAssertEqual(remoteReviews.insertedReviews.map(\.id), [review.id])
        XCTAssertEqual(remoteFavorites.addedSpotIDs, [spot.id])
        XCTAssertEqual(remoteProfile.savedProfiles.last?.displayName, "Migrated User")
        XCTAssertTrue(checkpointStore.isCompleted(for: userID))
    }

    func testMigrationRetrySkipsCompletedItems() async throws {
        let spot = makeMigrationSpot()
        try await localSpotRepository.addUserSpot(spot)
        localSpotIDs.insert(spot.id)

        let remoteSpots = StubSpotRepository()
        let migrator = makeMigrator(remoteSpotRepository: remoteSpots)

        _ = try await migrator.migrate(userID: userID) { _ in }
        _ = try await migrator.migrate(userID: userID) { _ in }

        XCTAssertEqual(remoteSpots.addedSpots.map(\.id), [spot.id])
    }

    private func makeMigrator(
        remoteSpotRepository: SpotRepository = StubSpotRepository(),
        remoteReviewRepository: ReviewRepository = StubReviewRepository(),
        remoteFavoritesRepository: FavoritesRepository = StubFavoritesRepository(),
        remoteProfileRepository: ProfileRepository = StubProfileRepository()
    ) -> LocalToRemoteMigrator {
        LocalToRemoteMigrator(
            localSpotRepository: localSpotRepository,
            remoteSpotRepository: remoteSpotRepository,
            localReviewRepository: localReviewRepository,
            remoteReviewRepository: remoteReviewRepository,
            localFavoritesRepository: localFavoritesRepository,
            remoteFavoritesRepository: remoteFavoritesRepository,
            localProfileRepository: localProfileRepository,
            remoteProfileRepository: remoteProfileRepository,
            imageStorage: StubMigrationImageStorage(),
            checkpointStore: checkpointStore
        )
    }

    private func makeMigrationSpot(id: UUID = UUID()) -> Spot {
        Spot(
            id: id,
            name: "Migration Spot",
            subtitle: "Local",
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
            lastConfirmed: ISO8601DateFormatter().date(from: "2026-05-21T20:00:00Z")!
        )
    }
}

struct StubMigrationImageStorage: ImageStorageProviding {
    func uploadSpotPhoto(_ data: Data) async throws -> String {
        "https://example.com/spot.jpg"
    }

    func uploadAvatar(_ data: Data, for userID: UUID) async throws -> String {
        "https://example.com/avatar.jpg"
    }

    func deleteImage(at url: String) async throws {}

    func publicURL(forObjectKey objectKey: String, bucket: SupabaseImageBucket) throws -> String {
        "https://example.com/\(bucket.rawValue)/\(objectKey)"
    }
}
