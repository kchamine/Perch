import Foundation

protocol ProfileRepository {
    func loadProfile() async throws -> UserProfile
    func saveProfile(_ profile: UserProfile) async throws
}

enum ProfileRepositoryError: LocalizedError, Equatable {
    case notAuthenticated
    case notFound
    case duplicateUsername
    case loadFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Sign in again before syncing your profile."
        case .notFound:
            return "No profile exists for this account yet."
        case .duplicateUsername:
            return "That handle is already taken. Choose a different one."
        case .loadFailed:
            return "Couldn't load your profile."
        case .saveFailed:
            return "Couldn't save your profile."
        }
    }
}

final class LocalProfileRepository: ProfileRepository {
    static let storageKey = "perch.localProfile"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadProfile() async throws -> UserProfile {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return .default
        }
        return decoded.normalized
    }

    func saveProfile(_ profile: UserProfile) async throws {
        guard let data = try? JSONEncoder().encode(profile.normalized) else {
            throw ProfileRepositoryError.saveFailed
        }
        defaults.set(data, forKey: Self.storageKey)
    }
}
