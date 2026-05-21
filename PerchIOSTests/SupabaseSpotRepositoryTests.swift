import XCTest
@testable import PerchIOS

final class SupabaseSpotRepositoryTests: XCTestCase {
    private let userID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

    func testLoadUserSpotsReturnsEmptyWhenUnauthenticated() async throws {
        let transport = StubSupabaseSpotsTransport()
        let repository = SupabaseSpotRepository(transport: transport, currentUserID: { nil })

        let spots = try await repository.loadUserSpots()

        XCTAssertTrue(spots.isEmpty)
        XCTAssertNil(transport.selectedOwnerUserID)
    }

    func testLoadUserSpotsSelectsByOwnerAndMapsRows() async throws {
        let transport = StubSupabaseSpotsTransport()
        let spot = makeSupabaseSpot()
        transport.rows = [SupabaseSpotRow(from: spot, ownerUserID: userID)]
        let repository = SupabaseSpotRepository(transport: transport, currentUserID: { self.userID })

        let spots = try await repository.loadUserSpots()

        XCTAssertEqual(transport.selectedOwnerUserID, userID)
        XCTAssertEqual(spots, [spot])
    }

    func testAddUserSpotPassesOwnerScopedRow() async throws {
        let transport = StubSupabaseSpotsTransport()
        let spot = makeSupabaseSpot()
        let repository = SupabaseSpotRepository(transport: transport, currentUserID: { self.userID })

        try await repository.addUserSpot(spot)

        XCTAssertEqual(transport.insertedRows.first?.id, spot.id)
        XCTAssertEqual(transport.insertedRows.first?.ownerUserID, userID)
    }

    func testUpdateUserSpotFiltersByID() async throws {
        let transport = StubSupabaseSpotsTransport()
        let spot = makeSupabaseSpot()
        let repository = SupabaseSpotRepository(transport: transport, currentUserID: { self.userID })

        try await repository.updateUserSpot(spot)

        XCTAssertEqual(transport.updatedRows.first?.row.id, spot.id)
        XCTAssertEqual(transport.updatedRows.first?.id, spot.id)
    }

    func testDeleteUserSpotsUsesIDList() async throws {
        let transport = StubSupabaseSpotsTransport()
        let first = UUID()
        let second = UUID()
        let repository = SupabaseSpotRepository(transport: transport, currentUserID: { self.userID })

        try await repository.deleteUserSpots(ids: [first, second])

        XCTAssertEqual(transport.deletedIDs, [first, second])
    }

    func testMutationsThrowWhenUnauthenticated() async {
        let transport = StubSupabaseSpotsTransport()
        let repository = SupabaseSpotRepository(transport: transport, currentUserID: { nil })
        let spot = makeSupabaseSpot()

        await XCTAssertThrowsAsyncError(try await repository.addUserSpot(spot), SupabaseSpotRepositoryError.notAuthenticated)
        await XCTAssertThrowsAsyncError(try await repository.updateUserSpot(spot), SupabaseSpotRepositoryError.notAuthenticated)
        await XCTAssertThrowsAsyncError(try await repository.deleteUserSpots(ids: [spot.id]), SupabaseSpotRepositoryError.notAuthenticated)
    }
}

final class StubSupabaseSpotsTransport: SupabaseSpotsTransport {
    var rows: [SupabaseSpotRow] = []
    var selectedOwnerUserID: UUID?
    var insertedRows: [SupabaseSpotRow] = []
    var updatedRows: [(row: SupabaseSpotRow, id: UUID)] = []
    var deletedIDs: Set<UUID> = []

    func select(ownerUserID: UUID) async throws -> [SupabaseSpotRow] {
        selectedOwnerUserID = ownerUserID
        return rows
    }

    func insert(_ row: SupabaseSpotRow) async throws {
        insertedRows.append(row)
    }

    func update(_ row: SupabaseSpotRow, id: UUID) async throws {
        updatedRows.append((row, id))
    }

    func delete(ids: Set<UUID>) async throws {
        deletedIDs = ids
    }
}

func XCTAssertThrowsAsyncError<T, E: Error & Equatable>(
    _ expression: @autoclosure () async throws -> T,
    _ expectedError: E,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error \(expectedError)", file: file, line: line)
    } catch let error as E {
        XCTAssertEqual(error, expectedError, file: file, line: line)
    } catch {
        XCTFail("Unexpected error \(error)", file: file, line: line)
    }
}
