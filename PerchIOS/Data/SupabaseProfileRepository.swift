import Foundation
import Supabase

struct ProfileRow: Codable, Equatable {
    let userID: UUID
    let displayName: String
    let username: String
    let bio: String?
    let homeNeighborhood: String?
    let avatarURL: String?
    let avatarSymbol: String?
    let perchStyle: String?
    let favoriteMoment: String?
    let defaultReviewName: String?
    let mapsAppPreference: String
    let joinedAt: Date
    let updatedAt: Date

    init(from profile: UserProfile, userID: UUID) {
        self.userID = userID
        self.displayName = profile.displayName
        self.username = profile.username
        self.bio = profile.bio
        self.homeNeighborhood = profile.homeNeighborhood
        self.avatarURL = profile.avatarURL.isEmpty ? nil : profile.avatarURL
        self.avatarSymbol = profile.avatarSymbol
        self.perchStyle = profile.perchStyle
        self.favoriteMoment = profile.favoriteMoment
        self.defaultReviewName = profile.defaultReviewName.rawValue
        self.mapsAppPreference = profile.mapsAppPreference.rawValue
        self.joinedAt = profile.joinedAt
        self.updatedAt = .now
    }

    func toModel() -> UserProfile {
        UserProfile(
            displayName: displayName,
            username: username,
            email: "",
            homeNeighborhood: homeNeighborhood ?? "",
            bio: bio ?? UserProfile.default.bio,
            defaultReviewName: defaultReviewName.flatMap(ReviewDisplayNameMode.init(rawValue:)) ?? .firstNameOnly,
            joinedAt: joinedAt,
            updatedAt: updatedAt,
            avatarURL: avatarURL ?? "",
            avatarSymbol: avatarSymbol ?? UserProfile.default.avatarSymbol,
            perchStyle: perchStyle ?? UserProfile.default.perchStyle,
            favoriteMoment: favoriteMoment ?? UserProfile.default.favoriteMoment,
            mapsAppPreference: MapsAppPreference(rawValue: mapsAppPreference) ?? .appleMaps
        )
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case displayName = "display_name"
        case username
        case bio
        case homeNeighborhood = "home_neighborhood"
        case avatarURL = "avatar_url"
        case avatarSymbol = "avatar_symbol"
        case perchStyle = "perch_style"
        case favoriteMoment = "favorite_moment"
        case defaultReviewName = "default_review_name"
        case mapsAppPreference = "maps_app_preference"
        case joinedAt = "joined_at"
        case updatedAt = "updated_at"
    }
}

protocol SupabaseProfilesTransport {
    func select(userID: UUID) async throws -> ProfileRow?
    func upsert(_ row: ProfileRow) async throws
}

final class SupabaseProfileRepository: ProfileRepository {
    private let transport: SupabaseProfilesTransport
    private let currentUserID: () -> UUID?

    init(client: SupabaseClient, currentUserID: @escaping () -> UUID?) {
        self.transport = SupabaseProfilesClientTransport(client: client)
        self.currentUserID = currentUserID
    }

    init(transport: SupabaseProfilesTransport, currentUserID: @escaping () -> UUID?) {
        self.transport = transport
        self.currentUserID = currentUserID
    }

    func loadProfile() async throws -> UserProfile {
        guard let userID = currentUserID() else { return .default }
        if let row = try await transport.select(userID: userID) {
            return row.toModel()
        }

        let profile = defaultProfile(for: userID)
        try await saveProfile(profile)
        return profile
    }

    func saveProfile(_ profile: UserProfile) async throws {
        guard let userID = currentUserID() else {
            throw ProfileRepositoryError.notAuthenticated
        }
        do {
            try await transport.upsert(ProfileRow(from: profile, userID: userID))
        } catch {
            if isDuplicateUsernameError(error) {
                throw ProfileRepositoryError.duplicateUsername
            }
            throw error
        }
    }

    private func defaultProfile(for userID: UUID) -> UserProfile {
        var profile = UserProfile.default
        let suffix = userID.uuidString
            .prefix(8)
            .lowercased()
        profile.username = UserProfile.sanitizedHandle("perch-\(suffix)")
        profile.joinedAt = .now
        profile.updatedAt = .now
        return profile
    }

    private func isDuplicateUsernameError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("duplicate")
            || message.contains("23505")
            || message.contains("profiles_username_key")
            || message.contains("already exists")
    }
}

struct SupabaseProfilesClientTransport: SupabaseProfilesTransport {
    let client: SupabaseClient

    func select(userID: UUID) async throws -> ProfileRow? {
        let rows: [ProfileRow] = try await client
            .from("profiles")
            .select()
            .eq("user_id", value: userID.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func upsert(_ row: ProfileRow) async throws {
        try await client
            .from("profiles")
            .upsert(row, onConflict: "user_id")
            .execute()
    }
}
