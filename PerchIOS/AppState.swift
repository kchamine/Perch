import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .explore
    @Published var pendingRevealSpot: Spot?
    @Published var hasCompletedOnboarding: Bool

    private let onboardingKey = "perch.hasCompletedOnboarding"

    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "perch.hasCompletedOnboarding")
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingKey)
    }

    func revealInExplore(_ spot: Spot) {
        pendingRevealSpot = spot
        selectedTab = .explore
    }

    func markRevealHandled(for spot: Spot) {
        guard pendingRevealSpot?.id == spot.id else { return }
        pendingRevealSpot = nil
    }
}

enum AppTab: Hashable {
    case explore
    case saved
    case addSpot
}
