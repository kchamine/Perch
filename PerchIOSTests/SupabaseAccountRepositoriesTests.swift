import XCTest
@testable import PerchIOS

final class SupabaseAccountRepositoriesTests: XCTestCase {
    private let userID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

    func testFavoritesLoadSelectsSignedInUser() async throws {
        let transport = StubSupabaseFavoritesTransport()
        let spotID = UUID()
        transport.rows = [FavoriteRow(userID: userID, spotID: spotID)]
        let repository = SupabaseFavoritesRepository(transport: transport, currentUserID: { self.userID })

        let favorites = try await repository.loadFavorites()

        XCTAssertEqual(transport.selectedUserID, userID)
        XCTAssertEqual(favorites, [spotID])
    }

    func testFavoritesMutationsRequireAuth() async {
        let repository = SupabaseFavoritesRepository(transport: StubSupabaseFavoritesTransport(), currentUserID: { nil })

        await XCTAssertThrowsAsyncError(try await repository.addFavorite(spotID: UUID()), SupabaseFavoritesRepositoryError.notAuthenticated)
        await XCTAssertThrowsAsyncError(try await repository.removeFavorites(ids: [UUID()]), SupabaseFavoritesRepositoryError.notAuthenticated)
    }

    func testReviewsMapRowsAndUseAuthorUserID() async throws {
        let transport = StubSupabaseReviewsTransport()
        let review = makeReview()
        transport.rows = [ReviewRow(from: review, authorUserID: userID)]
        let repository = SupabaseReviewRepository(transport: transport, currentUserID: { self.userID })

        let loaded = try await repository.loadReviews()
        try await repository.insert(review)
        try await repository.delete(id: review.id)

        XCTAssertEqual(transport.selectedAuthorUserID, userID)
        XCTAssertEqual(loaded, [review])
        XCTAssertEqual(transport.insertedRows.first?.authorUserID, userID)
        XCTAssertEqual(transport.deletedID, review.id)
    }

    func testReviewsMutationsRequireAuth() async {
        let repository = SupabaseReviewRepository(transport: StubSupabaseReviewsTransport(), currentUserID: { nil })

        await XCTAssertThrowsAsyncError(try await repository.insert(makeReview()), SupabaseReviewRepositoryError.notAuthenticated)
        await XCTAssertThrowsAsyncError(try await repository.delete(id: UUID()), SupabaseReviewRepositoryError.notAuthenticated)
    }

    func testProfileLoadAndSaveMapAccountRow() async throws {
        let transport = StubSupabaseProfilesTransport()
        var profile = UserProfile.default
        profile.displayName = "Kian"
        profile.username = "kian"
        profile.mapsAppPreference = .googleMaps
        transport.row = ProfileRow(from: profile, userID: userID)
        let repository = SupabaseProfileRepository(transport: transport, currentUserID: { self.userID })

        let loaded = try await repository.loadProfile()
        try await repository.saveProfile(profile)

        XCTAssertEqual(transport.selectedUserID, userID)
        XCTAssertEqual(loaded.displayName, "Kian")
        XCTAssertEqual(loaded.mapsAppPreference, .googleMaps)
        XCTAssertEqual(transport.upsertedRows.first?.userID, userID)
        XCTAssertEqual(transport.upsertedRows.first?.displayName, "Kian")
    }

    func testProfileLoadCreatesDefaultRowWhenMissing() async throws {
        let transport = StubSupabaseProfilesTransport()
        let repository = SupabaseProfileRepository(transport: transport, currentUserID: { self.userID })

        let loaded = try await repository.loadProfile()

        XCTAssertEqual(transport.selectedUserID, userID)
        XCTAssertEqual(transport.upsertedRows.first?.userID, userID)
        XCTAssertEqual(loaded.username, "perch-44444444")
        XCTAssertEqual(transport.upsertedRows.first?.username, "perch-44444444")
    }

    func testProfileSaveRequiresAuth() async {
        let repository = SupabaseProfileRepository(transport: StubSupabaseProfilesTransport(), currentUserID: { nil })

        await XCTAssertThrowsAsyncError(try await repository.saveProfile(.default), ProfileRepositoryError.notAuthenticated)
    }

    func testProfileDuplicateUsernameMapsToClearError() async {
        let transport = StubSupabaseProfilesTransport()
        transport.upsertError = NSError(domain: "PostgREST", code: 23505, userInfo: [NSLocalizedDescriptionKey: "duplicate key value violates unique constraint profiles_username_key"])
        let repository = SupabaseProfileRepository(transport: transport, currentUserID: { self.userID })

        await XCTAssertThrowsAsyncError(try await repository.saveProfile(.default), ProfileRepositoryError.duplicateUsername)
    }
}

final class StubSupabaseFavoritesTransport: SupabaseFavoritesTransport {
    var rows: [FavoriteRow] = []
    var selectedUserID: UUID?
    var insertedRows: [FavoriteRow] = []
    var deletedUserID: UUID?
    var deletedSpotIDs: Set<UUID> = []

    func select(userID: UUID) async throws -> [FavoriteRow] {
        selectedUserID = userID
        return rows
    }

    func insert(_ row: FavoriteRow) async throws {
        insertedRows.append(row)
    }

    func delete(userID: UUID, spotIDs: Set<UUID>) async throws {
        deletedUserID = userID
        deletedSpotIDs = spotIDs
    }
}

final class StubSupabaseReviewsTransport: SupabaseReviewsTransport {
    var rows: [ReviewRow] = []
    var selectedAuthorUserID: UUID?
    var insertedRows: [ReviewRow] = []
    var deletedID: UUID?

    func select(authorUserID: UUID) async throws -> [ReviewRow] {
        selectedAuthorUserID = authorUserID
        return rows
    }

    func insert(_ row: ReviewRow) async throws {
        insertedRows.append(row)
    }

    func delete(id: UUID) async throws {
        deletedID = id
    }
}

final class StubSupabaseProfilesTransport: SupabaseProfilesTransport {
    var row: ProfileRow?
    var selectedUserID: UUID?
    var upsertedRows: [ProfileRow] = []
    var upsertError: Error?

    func select(userID: UUID) async throws -> ProfileRow? {
        selectedUserID = userID
        return row
    }

    func upsert(_ row: ProfileRow) async throws {
        if let upsertError { throw upsertError }
        upsertedRows.append(row)
    }
}
