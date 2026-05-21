import Foundation
import Supabase

struct ReviewRow: Codable, Equatable {
    let id: UUID
    let spotID: UUID
    let authorUserID: UUID
    let authorName: String
    let title: String
    let note: String
    let settleInEase: Int
    let stayComfort: Int
    let viewPayoff: Int
    let calmFactor: Int
    let wouldReturn: Bool
    let bestFor: [String]
    let createdAt: Date
    let updatedAt: Date

    init(from review: SpotReview, authorUserID: UUID) {
        self.id = review.id
        self.spotID = review.spotID
        self.authorUserID = authorUserID
        self.authorName = review.authorName
        self.title = review.title
        self.note = review.note
        self.settleInEase = review.settleInEase
        self.stayComfort = review.stayComfort
        self.viewPayoff = review.viewPayoff
        self.calmFactor = review.calmFactor
        self.wouldReturn = review.wouldReturn
        self.bestFor = review.bestFor.map(\.rawValue)
        self.createdAt = review.createdAt
        self.updatedAt = review.updatedAt
    }

    func toModel() -> SpotReview {
        SpotReview(
            id: id,
            spotID: spotID,
            authorName: authorName,
            title: title,
            note: note,
            settleInEase: settleInEase,
            stayComfort: stayComfort,
            viewPayoff: viewPayoff,
            calmFactor: calmFactor,
            wouldReturn: wouldReturn,
            bestFor: bestFor.compactMap(PerchReviewMoment.init(rawValue:)),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case spotID = "spot_id"
        case authorUserID = "author_user_id"
        case authorName = "author_name"
        case title
        case note
        case settleInEase = "settle_in_ease"
        case stayComfort = "stay_comfort"
        case viewPayoff = "view_payoff"
        case calmFactor = "calm_factor"
        case wouldReturn = "would_return"
        case bestFor = "best_for"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

protocol SupabaseReviewsTransport {
    func select(authorUserID: UUID) async throws -> [ReviewRow]
    func insert(_ row: ReviewRow) async throws
    func delete(id: UUID) async throws
}

final class SupabaseReviewRepository: ReviewRepository {
    private let transport: SupabaseReviewsTransport
    private let currentUserID: () -> UUID?

    init(client: SupabaseClient, currentUserID: @escaping () -> UUID?) {
        self.transport = SupabaseReviewsClientTransport(client: client)
        self.currentUserID = currentUserID
    }

    init(transport: SupabaseReviewsTransport, currentUserID: @escaping () -> UUID?) {
        self.transport = transport
        self.currentUserID = currentUserID
    }

    func loadReviews() async throws -> [SpotReview] {
        guard let userID = currentUserID() else { return [] }
        return try await transport.select(authorUserID: userID).map { $0.toModel() }
    }

    func insert(_ review: SpotReview) async throws {
        let userID = try authenticatedUserID()
        try await transport.insert(ReviewRow(from: review, authorUserID: userID))
    }

    func delete(id: UUID) async throws {
        _ = try authenticatedUserID()
        try await transport.delete(id: id)
    }

    private func authenticatedUserID() throws -> UUID {
        guard let userID = currentUserID() else {
            throw SupabaseReviewRepositoryError.notAuthenticated
        }
        return userID
    }
}

struct SupabaseReviewsClientTransport: SupabaseReviewsTransport {
    let client: SupabaseClient

    func select(authorUserID: UUID) async throws -> [ReviewRow] {
        try await client
            .from("reviews")
            .select()
            .eq("author_user_id", value: authorUserID.uuidString)
            .execute()
            .value
    }

    func insert(_ row: ReviewRow) async throws {
        try await client
            .from("reviews")
            .insert(row)
            .execute()
    }

    func delete(id: UUID) async throws {
        try await client
            .from("reviews")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

enum SupabaseReviewRepositoryError: LocalizedError, Equatable {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Sign in again before syncing reviews."
        }
    }
}
