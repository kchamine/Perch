import Foundation

@MainActor
final class ReviewStore: ObservableObject {
    @Published private(set) var reviews: [SpotReview] = []
    @Published private(set) var loadError: String?

    private let repository: ReviewRepository

    init(repository: ReviewRepository = LocalReviewRepository()) {
        self.repository = repository
    }

    func reviews(for spotID: UUID) -> [SpotReview] {
        reviews
            .filter { $0.spotID == spotID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func addReview(
        spotID: UUID,
        authorName: String,
        title: String,
        note: String,
        settleInEase: Int,
        stayComfort: Int,
        viewPayoff: Int,
        calmFactor: Int,
        wouldReturn: Bool,
        bestFor: [PerchReviewMoment]
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let review = SpotReview(
            id: UUID(),
            spotID: spotID,
            authorName: authorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Local visitor" : authorName,
            title: trimmedTitle.isEmpty ? "Worth a pause" : trimmedTitle,
            note: trimmedNote,
            settleInEase: settleInEase,
            stayComfort: stayComfort,
            viewPayoff: viewPayoff,
            calmFactor: calmFactor,
            wouldReturn: wouldReturn,
            bestFor: bestFor,
            createdAt: .now,
            updatedAt: .now
        )
        reviews.append(review)
        Task { await persistInsert(review) }
    }

    func deleteReview(id: UUID) {
        guard let index = reviews.firstIndex(where: { $0.id == id }) else { return }
        let removed = reviews[index]
        reviews.remove(at: index)
        Task { await persistDelete(id: id, rollback: removed) }
    }

    func summary(for spotID: UUID) -> SpotReviewSummary {
        let scoped = reviews(for: spotID)
        guard !scoped.isEmpty else { return .empty }

        let count = Double(scoped.count)
        let returning = Double(scoped.filter(\.wouldReturn).count)

        func average(_ keyPath: KeyPath<SpotReview, Int>) -> Double {
            Double(scoped.map { $0[keyPath: keyPath] }.reduce(0, +)) / count
        }

        let topMoments = Array(
            Dictionary(grouping: scoped.flatMap(\.bestFor), by: \.self)
                .map { moment, entries in (moment: moment, count: entries.count) }
                .sorted {
                    if $0.count == $1.count {
                        return $0.moment.label < $1.moment.label
                    }
                    return $0.count > $1.count
                }
                .prefix(2)
                .map(\.moment)
        )

        return SpotReviewSummary(
            count: scoped.count,
            averageOverall: scoped.map(\.overallRating).reduce(0, +) / count,
            averageSettleInEase: average(\.settleInEase),
            averageStayComfort: average(\.stayComfort),
            averageViewPayoff: average(\.viewPayoff),
            averageCalmFactor: average(\.calmFactor),
            returnRate: returning / count,
            topMoments: topMoments
        )
    }

    func load() async {
        do {
            reviews = try await repository.loadReviews()
            loadError = nil
        } catch {
            reviews = []
            loadError = error.localizedDescription
        }
    }

    func clear() {
        reviews = []
        loadError = nil
    }

    private func persistInsert(_ review: SpotReview) async {
        do {
            try await repository.insert(review)
            loadError = nil
        } catch {
            reviews.removeAll { $0.id == review.id }
            loadError = error.localizedDescription
        }
    }

    private func persistDelete(id: UUID, rollback review: SpotReview) async {
        do {
            try await repository.delete(id: id)
            loadError = nil
        } catch {
            reviews.append(review)
            loadError = error.localizedDescription
        }
    }
}
