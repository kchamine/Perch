import XCTest
@testable import PerchIOS

@MainActor
final class ReviewStoreTests: XCTestCase {
    private var store: ReviewStore!
    private var repository: StubReviewRepository!

    override func setUp() async throws {
        repository = StubReviewRepository()
        store = ReviewStore(repository: repository)
    }

    override func tearDown() async throws {
        store = nil
        repository = nil
    }

    // MARK: - Helpers

    private func addReview(
        spotID: UUID,
        settleInEase: Int = 4,
        stayComfort: Int = 4,
        viewPayoff: Int = 4,
        calmFactor: Int = 4,
        wouldReturn: Bool = true,
        bestFor: [PerchReviewMoment] = [.soloReset]
    ) {
        store.addReview(
            spotID: spotID,
            authorName: "Tester",
            title: "Great spot",
            note: "Nice place",
            settleInEase: settleInEase,
            stayComfort: stayComfort,
            viewPayoff: viewPayoff,
            calmFactor: calmFactor,
            wouldReturn: wouldReturn,
            bestFor: bestFor
        )
    }

    // MARK: - addReview

    func testAddReview() {
        let spotID = UUID()
        addReview(spotID: spotID)
        XCTAssertEqual(store.reviews.count, 1)
        XCTAssertEqual(store.reviews(for: spotID).count, 1)
    }

    func testAddMultipleReviewsForSameSpot() {
        let spotID = UUID()
        addReview(spotID: spotID)
        addReview(spotID: spotID)
        XCTAssertEqual(store.reviews(for: spotID).count, 2)
    }

    func testReviewsForDifferentSpotsAreIsolated() {
        let spot1 = UUID()
        let spot2 = UUID()
        addReview(spotID: spot1)
        addReview(spotID: spot2)
        XCTAssertEqual(store.reviews(for: spot1).count, 1)
        XCTAssertEqual(store.reviews(for: spot2).count, 1)
    }

    func testReviewsReturnedMostRecentFirst() {
        let spotID = UUID()
        addReview(spotID: spotID)
        addReview(spotID: spotID)
        let reviews = store.reviews(for: spotID)
        XCTAssertGreaterThanOrEqual(reviews[0].createdAt, reviews[1].createdAt)
    }

    func testAuthorNameTrimsAndFallsBackToLocalVisitor() {
        let spotID = UUID()
        store.addReview(
            spotID: spotID,
            authorName: "   ",
            title: "Title",
            note: "Note",
            settleInEase: 4,
            stayComfort: 4,
            viewPayoff: 4,
            calmFactor: 4,
            wouldReturn: true,
            bestFor: []
        )
        XCTAssertEqual(store.reviews(for: spotID)[0].authorName, "Local visitor")
    }

    func testTitleFallsBackWhenEmpty() {
        let spotID = UUID()
        store.addReview(
            spotID: spotID,
            authorName: "Tester",
            title: "   ",
            note: "Note",
            settleInEase: 4,
            stayComfort: 4,
            viewPayoff: 4,
            calmFactor: 4,
            wouldReturn: true,
            bestFor: []
        )
        XCTAssertEqual(store.reviews(for: spotID)[0].title, "Worth a pause")
    }

    // MARK: - deleteReview

    func testDeleteReview() {
        let spotID = UUID()
        addReview(spotID: spotID)
        let reviewID = store.reviews(for: spotID)[0].id
        store.deleteReview(id: reviewID)
        XCTAssertTrue(store.reviews(for: spotID).isEmpty)
    }

    func testDeleteNonexistentReviewIsNoop() {
        let spotID = UUID()
        addReview(spotID: spotID)
        store.deleteReview(id: UUID()) // random ID
        XCTAssertEqual(store.reviews.count, 1)
    }

    // MARK: - summary

    func testSummaryEmptyWhenNoReviews() {
        let summary = store.summary(for: UUID())
        XCTAssertEqual(summary.count, 0)
        XCTAssertEqual(summary.averageOverall, 0)
    }

    func testSummaryCountMatchesReviews() {
        let spotID = UUID()
        addReview(spotID: spotID)
        addReview(spotID: spotID)
        XCTAssertEqual(store.summary(for: spotID).count, 2)
    }

    func testSummaryAverageOverallCorrect() {
        let spotID = UUID()
        // overallRating = (settleInEase + stayComfort + viewPayoff + calmFactor) / 4.0
        addReview(spotID: spotID, settleInEase: 5, stayComfort: 5, viewPayoff: 5, calmFactor: 5)
        addReview(spotID: spotID, settleInEase: 3, stayComfort: 3, viewPayoff: 3, calmFactor: 3)
        let summary = store.summary(for: spotID)
        // averageOverall = sum of overallRatings / count = (5 + 3) / 2 = 4.0
        XCTAssertEqual(summary.averageOverall, 4.0, accuracy: 0.01)
    }

    func testSummaryReturnRateAllWouldReturn() {
        let spotID = UUID()
        addReview(spotID: spotID, wouldReturn: true)
        addReview(spotID: spotID, wouldReturn: true)
        XCTAssertEqual(store.summary(for: spotID).returnRate, 1.0, accuracy: 0.01)
    }

    func testSummaryReturnRateNoneWouldReturn() {
        let spotID = UUID()
        addReview(spotID: spotID, wouldReturn: false)
        addReview(spotID: spotID, wouldReturn: false)
        XCTAssertEqual(store.summary(for: spotID).returnRate, 0.0, accuracy: 0.01)
    }

    func testSummaryReturnRatePartial() {
        let spotID = UUID()
        addReview(spotID: spotID, wouldReturn: true)
        addReview(spotID: spotID, wouldReturn: false)
        XCTAssertEqual(store.summary(for: spotID).returnRate, 0.5, accuracy: 0.01)
    }

    func testSummaryTopMoments() {
        let spotID = UUID()
        addReview(spotID: spotID, bestFor: [.reading, .soloReset])
        addReview(spotID: spotID, bestFor: [.reading])
        addReview(spotID: spotID, bestFor: [.coffeeBreak])
        let summary = store.summary(for: spotID)
        // reading appears 2 times, soloReset and coffeeBreak 1 each
        XCTAssertTrue(summary.topMoments.contains(.reading))
        XCTAssertLessThanOrEqual(summary.topMoments.count, 2)
    }

    func testSummaryAverageSettleInEase() {
        let spotID = UUID()
        addReview(spotID: spotID, settleInEase: 2, stayComfort: 4, viewPayoff: 4, calmFactor: 4)
        addReview(spotID: spotID, settleInEase: 4, stayComfort: 4, viewPayoff: 4, calmFactor: 4)
        let summary = store.summary(for: spotID)
        XCTAssertEqual(summary.averageSettleInEase, 3.0, accuracy: 0.01)
    }

    func testSummarySingleReview() {
        let spotID = UUID()
        addReview(spotID: spotID, settleInEase: 5, stayComfort: 5, viewPayoff: 5, calmFactor: 5, wouldReturn: true)
        let summary = store.summary(for: spotID)
        XCTAssertEqual(summary.count, 1)
        XCTAssertEqual(summary.averageOverall, 5.0, accuracy: 0.01)
        XCTAssertEqual(summary.returnRate, 1.0, accuracy: 0.01)
    }

    // MARK: - persistence

    func testReviewsPersistAcrossStoreInstances() async {
        let defaults = UserDefaults(suiteName: "com.perch.reviewtests.\(UUID().uuidString)")!
        let repository = LocalReviewRepository(defaults: defaults)
        let spotID = UUID()
        store = ReviewStore(repository: repository)
        addReview(spotID: spotID)
        await settleAsyncStoreWork()

        let store2 = ReviewStore(repository: LocalReviewRepository(defaults: defaults))
        await store2.load()
        XCTAssertEqual(store2.reviews(for: spotID).count, 1)
    }

    func testDeletePersistsAcrossStoreInstances() async {
        let defaults = UserDefaults(suiteName: "com.perch.reviewtests.\(UUID().uuidString)")!
        let repository = LocalReviewRepository(defaults: defaults)
        let spotID = UUID()
        store = ReviewStore(repository: repository)
        addReview(spotID: spotID)
        await settleAsyncStoreWork()
        let reviewID = store.reviews(for: spotID)[0].id
        store.deleteReview(id: reviewID)
        await settleAsyncStoreWork()

        let store2 = ReviewStore(repository: LocalReviewRepository(defaults: defaults))
        await store2.load()
        XCTAssertTrue(store2.reviews(for: spotID).isEmpty)
    }

    func testLoadUsesRepositoryReviews() async {
        let review = makeReview(spotID: UUID())
        repository.loadedReviews = [review]

        await store.load()

        XCTAssertEqual(store.reviews, [review])
    }

    func testInsertFailureRollsBackReview() async {
        repository.insertError = TestRepositoryError.failed

        addReview(spotID: UUID())
        await settleAsyncStoreWork()

        XCTAssertTrue(store.reviews.isEmpty)
        XCTAssertEqual(store.loadError, TestRepositoryError.failed.localizedDescription)
    }
}

final class StubReviewRepository: ReviewRepository {
    var loadedReviews: [SpotReview] = []
    var loadError: Error?
    var insertError: Error?
    var deleteError: Error?
    var insertedReviews: [SpotReview] = []
    var deletedIDs: [UUID] = []

    func loadReviews() async throws -> [SpotReview] {
        if let loadError { throw loadError }
        return loadedReviews
    }

    func insert(_ review: SpotReview) async throws {
        if let insertError { throw insertError }
        insertedReviews.append(review)
        loadedReviews.append(review)
    }

    func delete(id: UUID) async throws {
        if let deleteError { throw deleteError }
        deletedIDs.append(id)
        loadedReviews.removeAll { $0.id == id }
    }
}

func makeReview(
    id: UUID = UUID(),
    spotID: UUID = UUID(),
    authorName: String = "Tester"
) -> SpotReview {
    SpotReview(
        id: id,
        spotID: spotID,
        authorName: authorName,
        title: "Great spot",
        note: "Nice place",
        settleInEase: 4,
        stayComfort: 4,
        viewPayoff: 4,
        calmFactor: 4,
        wouldReturn: true,
        bestFor: [.soloReset],
        createdAt: .now,
        updatedAt: .now
    )
}
