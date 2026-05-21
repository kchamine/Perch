import Foundation
import Supabase

struct FavoriteRow: Codable, Equatable {
    let userID: UUID
    let spotID: UUID

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case spotID = "spot_id"
    }
}

protocol SupabaseFavoritesTransport {
    func select(userID: UUID) async throws -> [FavoriteRow]
    func insert(_ row: FavoriteRow) async throws
    func delete(userID: UUID, spotIDs: Set<UUID>) async throws
}

final class SupabaseFavoritesRepository: FavoritesRepository {
    private let transport: SupabaseFavoritesTransport
    private let currentUserID: () -> UUID?

    init(client: SupabaseClient, currentUserID: @escaping () -> UUID?) {
        self.transport = SupabaseFavoritesClientTransport(client: client)
        self.currentUserID = currentUserID
    }

    init(transport: SupabaseFavoritesTransport, currentUserID: @escaping () -> UUID?) {
        self.transport = transport
        self.currentUserID = currentUserID
    }

    func loadFavorites() async throws -> Set<UUID> {
        guard let userID = currentUserID() else { return [] }
        return Set(try await transport.select(userID: userID).map(\.spotID))
    }

    func addFavorite(spotID: UUID) async throws {
        let userID = try authenticatedUserID()
        do {
            try await transport.insert(FavoriteRow(userID: userID, spotID: spotID))
        } catch {
            if isDuplicateKeyError(error) { return }
            throw error
        }
    }

    func removeFavorites(ids: Set<UUID>) async throws {
        let userID = try authenticatedUserID()
        guard !ids.isEmpty else { return }
        try await transport.delete(userID: userID, spotIDs: ids)
    }

    private func authenticatedUserID() throws -> UUID {
        guard let userID = currentUserID() else {
            throw SupabaseFavoritesRepositoryError.notAuthenticated
        }
        return userID
    }

    private func isDuplicateKeyError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("duplicate") || message.contains("23505") || message.contains("already exists")
    }
}

struct SupabaseFavoritesClientTransport: SupabaseFavoritesTransport {
    let client: SupabaseClient

    func select(userID: UUID) async throws -> [FavoriteRow] {
        try await client
            .from("favorites")
            .select("user_id,spot_id")
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value
    }

    func insert(_ row: FavoriteRow) async throws {
        try await client
            .from("favorites")
            .insert(row)
            .execute()
    }

    func delete(userID: UUID, spotIDs: Set<UUID>) async throws {
        try await client
            .from("favorites")
            .delete()
            .eq("user_id", value: userID.uuidString)
            .in("spot_id", values: spotIDs.map(\.uuidString))
            .execute()
    }
}

enum SupabaseFavoritesRepositoryError: LocalizedError, Equatable {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Sign in again before syncing favorites."
        }
    }
}
