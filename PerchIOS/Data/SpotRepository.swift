import Foundation

protocol SpotRepository {
    func loadSeededSpots() async throws -> [Spot]
    func loadUserSpots() async throws -> [Spot]
    func addUserSpot(_ spot: Spot) async throws
    func updateUserSpot(_ spot: Spot) async throws
    func deleteUserSpots(ids: Set<UUID>) async throws
}
