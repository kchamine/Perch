import Foundation
import SwiftUI

struct LocalMigrationSummary: Equatable {
    let spotCount: Int
    let reviewCount: Int
    let favoriteCount: Int
    let hasProfile: Bool

    var totalItems: Int {
        spotCount + reviewCount + favoriteCount + (hasProfile ? 1 : 0)
    }

    var hasData: Bool {
        totalItems > 0
    }
}

struct LocalMigrationProgress: Equatable {
    let phase: String
    let completed: Int
    let total: Int
    let detail: String
}

struct LocalMigrationFailure: Identifiable, Equatable {
    let id = UUID()
    let itemID: String
    let phase: String
    let message: String
}

struct LocalMigrationResult: Equatable {
    let summary: LocalMigrationSummary
    let failures: [LocalMigrationFailure]

    var didComplete: Bool {
        failures.isEmpty
    }
}

enum LocalMigrationSheetMode: Identifiable {
    case prompt
    case progress

    var id: String {
        switch self {
        case .prompt: "prompt"
        case .progress: "progress"
        }
    }
}

@MainActor
final class LocalDataMigrationStore: ObservableObject {
    @Published var sheetMode: LocalMigrationSheetMode?
    @Published private(set) var summary = LocalMigrationSummary(spotCount: 0, reviewCount: 0, favoriteCount: 0, hasProfile: false)
    @Published private(set) var progress = LocalMigrationProgress(phase: "Ready", completed: 0, total: 0, detail: "")
    @Published private(set) var failures: [LocalMigrationFailure] = []
    @Published private(set) var isRunning = false
    @Published private(set) var didFinish = false
    @Published private(set) var completedRunID = UUID()
    @Published private(set) var statusMessage: String?

    private let migrator: LocalToRemoteMigrating?
    private let currentUserID: () -> UUID?

    var isAvailable: Bool {
        migrator != nil
    }

    init(migrator: LocalToRemoteMigrating?, currentUserID: @escaping () -> UUID?) {
        self.migrator = migrator
        self.currentUserID = currentUserID
    }

    func evaluateAfterSignIn() async {
        guard let migrator, let userID = currentUserID(), !migrator.isCompleted(for: userID) else { return }
        do {
            let summary = try await migrator.localSummary()
            guard summary.hasData else { return }
            self.summary = summary
            progress = LocalMigrationProgress(phase: "Ready", completed: 0, total: summary.totalItems, detail: summaryText(for: summary))
            failures = []
            didFinish = false
            statusMessage = nil
            sheetMode = .prompt
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func presentManualSync() async {
        guard let migrator else {
            statusMessage = "Supabase sync is not configured in this build."
            return
        }
        do {
            if let userID = currentUserID(), migrator.isCompleted(for: userID) {
                statusMessage = "Local data sync already completed for this account."
                return
            }
            let summary = try await migrator.localSummary()
            guard summary.hasData else {
                statusMessage = "No local-only data is waiting to sync."
                return
            }
            self.summary = summary
            progress = LocalMigrationProgress(phase: "Ready", completed: 0, total: summary.totalItems, detail: summaryText(for: summary))
            failures = []
            didFinish = false
            statusMessage = nil
            sheetMode = .prompt
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func dismissPrompt() {
        sheetMode = nil
    }

    func startMigration() async {
        guard let migrator, let userID = currentUserID(), !isRunning else { return }
        isRunning = true
        didFinish = false
        failures = []
        statusMessage = nil
        sheetMode = .progress

        do {
            let result = try await migrator.migrate(userID: userID) { [weak self] progress in
                await MainActor.run {
                    self?.progress = progress
                }
            }
            summary = result.summary
            failures = result.failures
            didFinish = true
            if result.didComplete {
                completedRunID = UUID()
                progress = LocalMigrationProgress(
                    phase: "Complete",
                    completed: result.summary.totalItems,
                    total: result.summary.totalItems,
                    detail: "Local data is now backed by your Perch account. Local files are kept as a backup."
                )
            } else {
                progress = LocalMigrationProgress(
                    phase: "Needs retry",
                    completed: max(0, result.summary.totalItems - result.failures.count),
                    total: result.summary.totalItems,
                    detail: "Some items did not sync. Retry will skip anything already migrated."
                )
            }
        } catch {
            failures = [
                LocalMigrationFailure(itemID: "migration", phase: "Migration", message: error.localizedDescription)
            ]
            didFinish = true
            progress = LocalMigrationProgress(phase: "Needs retry", completed: 0, total: summary.totalItems, detail: error.localizedDescription)
        }

        isRunning = false
    }

    func closeProgress() {
        guard !isRunning else { return }
        sheetMode = nil
    }

    private func summaryText(for summary: LocalMigrationSummary) -> String {
        var parts: [String] = []
        if summary.spotCount > 0 { parts.append("\(summary.spotCount) spots") }
        if summary.reviewCount > 0 { parts.append("\(summary.reviewCount) reviews") }
        if summary.favoriteCount > 0 { parts.append("\(summary.favoriteCount) favorites") }
        if summary.hasProfile { parts.append("profile") }
        return parts.joined(separator: ", ")
    }
}

protocol LocalToRemoteMigrating {
    func localSummary() async throws -> LocalMigrationSummary
    func isCompleted(for userID: UUID) -> Bool
    func migrate(
        userID: UUID,
        progress: @escaping (LocalMigrationProgress) async -> Void
    ) async throws -> LocalMigrationResult
}

final class LocalToRemoteMigrator: LocalToRemoteMigrating {
    private let localSpotRepository: LocalSpotRepository
    private let remoteSpotRepository: SpotRepository
    private let localReviewRepository: LocalReviewRepository
    private let remoteReviewRepository: ReviewRepository
    private let localFavoritesRepository: LocalFavoritesRepository
    private let remoteFavoritesRepository: FavoritesRepository
    private let localProfileRepository: LocalProfileRepository
    private let remoteProfileRepository: ProfileRepository
    private let imageStore: ImageStore
    private let imageStorage: ImageStorageProviding
    private let checkpointStore: LocalMigrationCheckpointStore

    init(
        localSpotRepository: LocalSpotRepository = LocalSpotRepository(),
        remoteSpotRepository: SpotRepository,
        localReviewRepository: LocalReviewRepository = LocalReviewRepository(),
        remoteReviewRepository: ReviewRepository,
        localFavoritesRepository: LocalFavoritesRepository = LocalFavoritesRepository(),
        remoteFavoritesRepository: FavoritesRepository,
        localProfileRepository: LocalProfileRepository = LocalProfileRepository(),
        remoteProfileRepository: ProfileRepository,
        imageStore: ImageStore = ImageStore(),
        imageStorage: ImageStorageProviding,
        checkpointStore: LocalMigrationCheckpointStore = LocalMigrationCheckpointStore()
    ) {
        self.localSpotRepository = localSpotRepository
        self.remoteSpotRepository = remoteSpotRepository
        self.localReviewRepository = localReviewRepository
        self.remoteReviewRepository = remoteReviewRepository
        self.localFavoritesRepository = localFavoritesRepository
        self.remoteFavoritesRepository = remoteFavoritesRepository
        self.localProfileRepository = localProfileRepository
        self.remoteProfileRepository = remoteProfileRepository
        self.imageStore = imageStore
        self.imageStorage = imageStorage
        self.checkpointStore = checkpointStore
    }

    func localSummary() async throws -> LocalMigrationSummary {
        let spots = try await localSpotRepository.loadUserSpots()
        let reviews = try await localReviewRepository.loadReviews()
        let favorites = try await localFavoritesRepository.loadFavorites()
        return LocalMigrationSummary(
            spotCount: spots.count,
            reviewCount: reviews.count,
            favoriteCount: favorites.count,
            hasProfile: localProfileRepository.hasSavedProfile()
        )
    }

    func isCompleted(for userID: UUID) -> Bool {
        checkpointStore.isCompleted(for: userID)
    }

    func migrate(
        userID: UUID,
        progress: @escaping (LocalMigrationProgress) async -> Void
    ) async throws -> LocalMigrationResult {
        let spots = try await localSpotRepository.loadUserSpots()
        let reviews = try await localReviewRepository.loadReviews()
        let favorites = try await localFavoritesRepository.loadFavorites()
        let hasProfile = localProfileRepository.hasSavedProfile()
        let summary = LocalMigrationSummary(
            spotCount: spots.count,
            reviewCount: reviews.count,
            favoriteCount: favorites.count,
            hasProfile: hasProfile
        )

        var checkpoint = checkpointStore.checkpoint(for: userID)
        var failures: [LocalMigrationFailure] = []
        var completed = checkpoint.completedCount(in: summary)

        await progress(LocalMigrationProgress(phase: "Starting", completed: completed, total: summary.totalItems, detail: "Preparing local data"))

        for spot in spots where !checkpoint.spotIDs.contains(spot.id) {
            await progress(LocalMigrationProgress(phase: "Spots", completed: completed, total: summary.totalItems, detail: spot.name))
            do {
                var migratedSpot = spot
                if let localPath = localFilePath(from: spot.photoURL) {
                    guard let data = imageStore.imageData(for: localPath) else {
                        throw LocalMigrationError.missingLocalImage
                    }
                    migratedSpot.photoURL = try await imageStorage.uploadSpotPhoto(data)
                }

                if let supabaseRepository = remoteSpotRepository as? SupabaseSpotRepository {
                    try await supabaseRepository.addMigratedUserSpot(migratedSpot, createdAt: spot.lastConfirmed)
                } else {
                    try await remoteSpotRepository.addUserSpot(migratedSpot)
                }
                checkpoint.spotIDs.insert(spot.id)
                checkpointStore.save(checkpoint, for: userID)
                completed += 1
            } catch {
                failures.append(failure(for: spot.id, phase: "Spots", error: error))
            }
        }

        for review in reviews where !checkpoint.reviewIDs.contains(review.id) {
            await progress(LocalMigrationProgress(phase: "Reviews", completed: completed, total: summary.totalItems, detail: review.title))
            do {
                try await remoteReviewRepository.insert(review)
                checkpoint.reviewIDs.insert(review.id)
                checkpointStore.save(checkpoint, for: userID)
                completed += 1
            } catch {
                failures.append(failure(for: review.id, phase: "Reviews", error: error))
            }
        }

        for favoriteID in favorites where !checkpoint.favoriteSpotIDs.contains(favoriteID) {
            await progress(LocalMigrationProgress(phase: "Favorites", completed: completed, total: summary.totalItems, detail: favoriteID.uuidString))
            do {
                try await remoteFavoritesRepository.addFavorite(spotID: favoriteID)
                checkpoint.favoriteSpotIDs.insert(favoriteID)
                checkpointStore.save(checkpoint, for: userID)
                completed += 1
            } catch {
                failures.append(failure(for: favoriteID, phase: "Favorites", error: error))
            }
        }

        if hasProfile && !checkpoint.profileMigrated {
            await progress(LocalMigrationProgress(phase: "Profile", completed: completed, total: summary.totalItems, detail: "Profile details"))
            do {
                var profile = try await localProfileRepository.loadProfile()
                if let localPath = localFilePath(from: profile.avatarURL) {
                    guard let data = imageStore.imageData(for: localPath) else {
                        throw LocalMigrationError.missingLocalImage
                    }
                    profile.avatarURL = try await imageStorage.uploadAvatar(data, for: userID)
                }
                try await remoteProfileRepository.saveProfile(profile)
                checkpoint.profileMigrated = true
                checkpointStore.save(checkpoint, for: userID)
                completed += 1
            } catch {
                failures.append(LocalMigrationFailure(itemID: "profile", phase: "Profile", message: error.localizedDescription))
            }
        }

        if failures.isEmpty {
            checkpoint.completed = true
            checkpointStore.save(checkpoint, for: userID)
        }

        await progress(LocalMigrationProgress(phase: failures.isEmpty ? "Complete" : "Needs retry", completed: completed, total: summary.totalItems, detail: failures.isEmpty ? "All local data synced" : "\(failures.count) items need retry"))
        return LocalMigrationResult(summary: summary, failures: failures)
    }

    private func localFilePath(from value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard URL(string: value)?.scheme == nil else { return nil }
        return value
    }

    private func failure(for id: UUID, phase: String, error: Error) -> LocalMigrationFailure {
        LocalMigrationFailure(itemID: id.uuidString, phase: phase, message: error.localizedDescription)
    }
}

final class LocalMigrationCheckpointStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func checkpoint(for userID: UUID) -> LocalMigrationCheckpoint {
        guard let data = defaults.data(forKey: checkpointKey(for: userID)),
              let checkpoint = try? decoder.decode(LocalMigrationCheckpoint.self, from: data) else {
            return LocalMigrationCheckpoint()
        }
        return checkpoint
    }

    func save(_ checkpoint: LocalMigrationCheckpoint, for userID: UUID) {
        guard let data = try? encoder.encode(checkpoint) else { return }
        defaults.set(data, forKey: checkpointKey(for: userID))
    }

    func isCompleted(for userID: UUID) -> Bool {
        checkpoint(for: userID).completed
    }

    private func checkpointKey(for userID: UUID) -> String {
        "perch.localMigration.\(userID.uuidString)"
    }
}

struct LocalMigrationCheckpoint: Codable, Equatable {
    var spotIDs: Set<UUID> = []
    var reviewIDs: Set<UUID> = []
    var favoriteSpotIDs: Set<UUID> = []
    var profileMigrated = false
    var completed = false

    func completedCount(in summary: LocalMigrationSummary) -> Int {
        min(spotIDs.count, summary.spotCount)
            + min(reviewIDs.count, summary.reviewCount)
            + min(favoriteSpotIDs.count, summary.favoriteCount)
            + (profileMigrated && summary.hasProfile ? 1 : 0)
    }
}

enum LocalMigrationError: LocalizedError {
    case missingLocalImage

    var errorDescription: String? {
        switch self {
        case .missingLocalImage:
            return "The local image file could not be found."
        }
    }
}
