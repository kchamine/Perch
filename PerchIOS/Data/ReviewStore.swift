import Foundation

@MainActor
final class ReviewStore: ObservableObject {
    @Published private(set) var reviews: [SpotReview] = []

    private let defaults: UserDefaults
    private let key = "perch.reviews"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
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
        persist()
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

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SpotReview].self, from: data) else {
            reviews = []
            return
        }
        reviews = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(reviews) {
            defaults.set(data, forKey: key)
        }
    }
}
