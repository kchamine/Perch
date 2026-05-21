import Foundation

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profile: UserProfile = .default
    @Published private(set) var loadError: String?

    private let repository: ProfileRepository

    init(repository: ProfileRepository = LocalProfileRepository()) {
        self.repository = repository
    }

    func load() async {
        do {
            profile = try await repository.loadProfile().normalized
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    func update(_ mutate: (inout UserProfile) -> Void) {
        var next = profile
        mutate(&next)
        next = next.normalized
        next.updatedAt = .now
        profile = next
        Task { await save(next) }
    }

    func clear() {
        profile = .default
        loadError = nil
    }

    private func save(_ profile: UserProfile) async {
        do {
            try await repository.saveProfile(profile)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}
