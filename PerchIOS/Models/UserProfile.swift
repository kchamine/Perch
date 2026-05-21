import Foundation

struct UserProfile: Codable, Equatable {
    static let defaultHandle = "perch-local"
    static let maxHandleLength = 24

    var displayName: String
    var username: String
    var email: String
    var homeNeighborhood: String
    var bio: String
    var defaultReviewName: ReviewDisplayNameMode
    var joinedAt: Date
    var updatedAt: Date
    var avatarURL: String
    var avatarSymbol: String
    var perchStyle: String
    var favoriteMoment: String
    var mapsAppPreference: MapsAppPreference

    static let `default` = UserProfile(
        displayName: "Local Perch Keeper",
        username: defaultHandle,
        email: "",
        homeNeighborhood: "",
        bio: "Keeping a short list of dependable places to sit, pause, and reset.",
        defaultReviewName: .firstNameOnly,
        joinedAt: .now,
        updatedAt: .now,
        avatarURL: "",
        avatarSymbol: "leaf.circle.fill",
        perchStyle: "Quiet benches, soft light, easy coffee escapes.",
        favoriteMoment: "Late afternoon reset",
        mapsAppPreference: .appleMaps
    )

    init(
        displayName: String,
        username: String,
        email: String,
        homeNeighborhood: String,
        bio: String,
        defaultReviewName: ReviewDisplayNameMode,
        joinedAt: Date,
        updatedAt: Date,
        avatarURL: String,
        avatarSymbol: String,
        perchStyle: String,
        favoriteMoment: String,
        mapsAppPreference: MapsAppPreference = .appleMaps
    ) {
        self.displayName = displayName
        self.username = Self.sanitizedHandle(username)
        self.email = email
        self.homeNeighborhood = homeNeighborhood
        self.bio = bio
        self.defaultReviewName = defaultReviewName
        self.joinedAt = joinedAt
        self.updatedAt = updatedAt
        self.avatarURL = avatarURL
        self.avatarSymbol = avatarSymbol
        self.perchStyle = perchStyle
        self.favoriteMoment = favoriteMoment
        self.mapsAppPreference = mapsAppPreference
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? UserProfile.default.displayName
        username = Self.sanitizedHandle(
            try container.decodeIfPresent(String.self, forKey: .username) ?? UserProfile.default.username
        )
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? UserProfile.default.email
        homeNeighborhood = try container.decodeIfPresent(String.self, forKey: .homeNeighborhood) ?? UserProfile.default.homeNeighborhood
        bio = try container.decodeIfPresent(String.self, forKey: .bio) ?? UserProfile.default.bio
        defaultReviewName = try container.decodeIfPresent(ReviewDisplayNameMode.self, forKey: .defaultReviewName) ?? UserProfile.default.defaultReviewName
        joinedAt = try container.decodeIfPresent(Date.self, forKey: .joinedAt) ?? .now
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
            ?? container.decodeIfPresent(String.self, forKey: .avatarURLSnake)
            ?? container.decodeIfPresent(String.self, forKey: .avatarImagePath)
            ?? UserProfile.default.avatarURL
        avatarSymbol = try container.decodeIfPresent(String.self, forKey: .avatarSymbol) ?? UserProfile.default.avatarSymbol
        perchStyle = try container.decodeIfPresent(String.self, forKey: .perchStyle) ?? UserProfile.default.perchStyle
        favoriteMoment = try container.decodeIfPresent(String.self, forKey: .favoriteMoment) ?? UserProfile.default.favoriteMoment
        mapsAppPreference = try container.decodeIfPresent(MapsAppPreference.self, forKey: .mapsAppPreference) ?? UserProfile.default.mapsAppPreference

        try Self.consumeLegacyAccountResidue(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(Self.sanitizedHandle(username), forKey: .username)
        try container.encode(email, forKey: .email)
        try container.encode(homeNeighborhood, forKey: .homeNeighborhood)
        try container.encode(bio, forKey: .bio)
        try container.encode(defaultReviewName, forKey: .defaultReviewName)
        try container.encode(joinedAt, forKey: .joinedAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(avatarURL, forKey: .avatarURL)
        try container.encode(avatarSymbol, forKey: .avatarSymbol)
        try container.encode(perchStyle, forKey: .perchStyle)
        try container.encode(favoriteMoment, forKey: .favoriteMoment)
        try container.encode(mapsAppPreference, forKey: .mapsAppPreference)
    }

    var reviewAuthorName: String {
        switch defaultReviewName {
        case .firstNameOnly:
            let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return usernameFallback }
            return trimmed.split(separator: " ").first.map(String.init) ?? trimmed
        case .username:
            return usernameFallback
        case .fullName:
            let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? usernameFallback : trimmed
        }
    }

    var hasCustomAvatar: Bool {
        !avatarURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var normalized: UserProfile {
        var copy = self
        copy.username = Self.sanitizedHandle(copy.username)
        return copy
    }

    private var usernameFallback: String {
        "@\(Self.sanitizedHandle(username))"
    }
}

extension UserProfile {
    static func sanitizedHandle(_ value: String) -> String {
        let lowered = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let allowedScalars = lowered.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar) || scalar.value == 45 || scalar.value == 95
        }

        let filtered = String(String.UnicodeScalarView(allowedScalars))
        let collapsed = collapseHandleSeparators(filtered)
        let bounded = String(collapsed.prefix(maxHandleLength))
        let trimmed = bounded.trimmingCharacters(in: CharacterSet(charactersIn: "-_"))

        guard trimmed.count >= 3 else { return defaultHandle }
        guard trimmed.contains(where: { $0.isLetter || $0.isNumber }) else { return defaultHandle }
        return trimmed
    }

    private static func collapseHandleSeparators(_ value: String) -> String {
        var result = ""
        var previousWasSeparator = false

        for character in value {
            let isSeparator = character == "-" || character == "_"
            if isSeparator {
                guard !previousWasSeparator else { continue }
                previousWasSeparator = true
            } else {
                previousWasSeparator = false
            }
            result.append(character)
        }

        return result
    }

    private static func consumeLegacyAccountResidue(from decoder: Decoder) throws {
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        _ = try legacyContainer.decodeIfPresent(String.self, forKey: .passwordHint)
        _ = try legacyContainer.decodeIfPresent(Bool.self, forKey: .allowOfflineLock)
    }

    private enum CodingKeys: String, CodingKey {
        case displayName
        case username
        case email
        case homeNeighborhood
        case bio
        case defaultReviewName
        case joinedAt
        case updatedAt
        case avatarURL
        case avatarURLSnake = "avatar_url"
        case avatarImagePath
        case avatarSymbol
        case perchStyle
        case favoriteMoment
        case mapsAppPreference
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case passwordHint
        case allowOfflineLock
    }
}

enum MapsAppPreference: String, Codable, CaseIterable, Identifiable {
    case appleMaps
    case googleMaps

    var id: String { rawValue }

    var label: String {
        switch self {
        case .appleMaps: "Apple Maps"
        case .googleMaps: "Google Maps"
        }
    }
}

enum ReviewDisplayNameMode: String, Codable, CaseIterable, Identifiable {
    case firstNameOnly
    case username
    case fullName

    var id: String { rawValue }

    var label: String {
        switch self {
        case .firstNameOnly: "First name only"
        case .username: "Username"
        case .fullName: "Full name"
        }
    }
}
