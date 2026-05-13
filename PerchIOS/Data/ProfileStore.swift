import Foundation

@MainActor
final class ProfileStore: ObservableObject {
    @Published var profile: UserProfile {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private let key = "perch.localProfile"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.profile = decoded.normalized
        } else {
            self.profile = .default
        }
    }

    func update(_ mutate: (inout UserProfile) -> Void) {
        var next = profile
        mutate(&next)
        next = next.normalized
        next.updatedAt = .now
        profile = next
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: key)
        }
    }
}
