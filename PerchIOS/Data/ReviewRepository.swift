import Foundation

protocol ReviewRepository {
    func loadReviews() async throws -> [SpotReview]
    func insert(_ review: SpotReview) async throws
    func delete(id: UUID) async throws
}

enum ReviewRepositoryError: LocalizedError {
    case decodingFailed
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .decodingFailed:
            return "Couldn't load saved reviews."
        case .encodingFailed:
            return "Couldn't save reviews."
        }
    }
}
