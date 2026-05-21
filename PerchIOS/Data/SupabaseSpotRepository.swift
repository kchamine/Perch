import Foundation
import Supabase

protocol SupabaseSpotsTransport {
    func select(ownerUserID: UUID) async throws -> [SupabaseSpotRow]
    func insert(_ row: SupabaseSpotRow) async throws
    func update(_ row: SupabaseSpotRow, id: UUID) async throws
    func delete(ids: Set<UUID>) async throws
}

final class SupabaseSpotRepository: SpotRepository {
    private let seededRepository: LocalSpotRepository
    private let transport: SupabaseSpotsTransport
    private let currentUserID: () -> UUID?

    init(
        client: SupabaseClient,
        currentUserID: @escaping () -> UUID?,
        seededRepository: LocalSpotRepository = LocalSpotRepository()
    ) {
        self.seededRepository = seededRepository
        self.transport = SupabaseSpotsClientTransport(client: client)
        self.currentUserID = currentUserID
    }

    init(
        transport: SupabaseSpotsTransport,
        currentUserID: @escaping () -> UUID?,
        seededRepository: LocalSpotRepository = LocalSpotRepository()
    ) {
        self.seededRepository = seededRepository
        self.transport = transport
        self.currentUserID = currentUserID
    }

    func loadSeededSpots() async throws -> [Spot] {
        try await seededRepository.loadSeededSpots()
    }

    func loadUserSpots() async throws -> [Spot] {
        guard let userID = currentUserID() else { return [] }
        return try await transport
            .select(ownerUserID: userID)
            .map { $0.toSpot() }
    }

    func addUserSpot(_ spot: Spot) async throws {
        let userID = try authenticatedUserID()
        try await transport.insert(SupabaseSpotRow(from: spot, ownerUserID: userID))
    }

    func addMigratedUserSpot(_ spot: Spot, createdAt: Date) async throws {
        let userID = try authenticatedUserID()
        try await transport.insert(
            SupabaseSpotRow(
                from: spot,
                ownerUserID: userID,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        )
    }

    func updateUserSpot(_ spot: Spot) async throws {
        let userID = try authenticatedUserID()
        try await transport.update(SupabaseSpotRow(from: spot, ownerUserID: userID), id: spot.id)
    }

    func deleteUserSpots(ids: Set<UUID>) async throws {
        _ = try authenticatedUserID()
        guard !ids.isEmpty else { return }
        try await transport.delete(ids: ids)
    }

    private func authenticatedUserID() throws -> UUID {
        guard let userID = currentUserID() else {
            throw SupabaseSpotRepositoryError.notAuthenticated
        }
        return userID
    }
}

struct SupabaseSpotsClientTransport: SupabaseSpotsTransport {
    let client: SupabaseClient

    func select(ownerUserID: UUID) async throws -> [SupabaseSpotRow] {
        try await client
            .from("spots")
            .select()
            .eq("owner_user_id", value: ownerUserID.uuidString)
            .execute()
            .value
    }

    func insert(_ row: SupabaseSpotRow) async throws {
        try await client
            .from("spots")
            .insert(row)
            .execute()
    }

    func update(_ row: SupabaseSpotRow, id: UUID) async throws {
        try await client
            .from("spots")
            .update(row)
            .eq("id", value: id.uuidString)
            .execute()
    }

    func delete(ids: Set<UUID>) async throws {
        try await client
            .from("spots")
            .delete()
            .in("id", values: ids.map(\.uuidString))
            .execute()
    }
}

enum SupabaseSpotRepositoryError: LocalizedError, Equatable {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Sign in again before syncing spots."
        }
    }
}
