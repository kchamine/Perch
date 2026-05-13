import Foundation

protocol SpotRepository {
    func loadSeededSpots() throws -> [Spot]
    func loadUserSpots() throws -> [Spot]
    func saveUserSpots(_ spots: [Spot]) throws
}
