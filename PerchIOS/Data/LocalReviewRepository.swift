import Foundation

final class LocalReviewRepository: ReviewRepository {
    private let defaults: UserDefaults
    private let key = "perch.reviews"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadReviews() async throws -> [SpotReview] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return try JSONDecoder().decode([SpotReview].self, from: data)
    }

    func insert(_ review: SpotReview) async throws {
        var reviews = try await loadReviews()
        reviews.append(review)
        try persist(reviews)
    }

    func delete(id: UUID) async throws {
        var reviews = try await loadReviews()
        reviews.removeAll { $0.id == id }
        try persist(reviews)
    }

    private func persist(_ reviews: [SpotReview]) throws {
        let data = try JSONEncoder().encode(reviews)
        defaults.set(data, forKey: key)
    }
}
