import SwiftUI

@main
struct PerchIOSApp: App {
    @StateObject private var store: SpotStore
    @StateObject private var favorites = FavoritesStore()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var appState = AppState()
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var reviewStore = ReviewStore()
    @StateObject private var authStore: AuthStore

    init() {
        let authStore = AuthStore()
        _authStore = StateObject(wrappedValue: authStore)

        let repository: SpotRepository
        if let client = SupabaseClientProvider.shared {
            repository = SupabaseSpotRepository(
                client: client,
                currentUserID: { authStore.currentUser?.id }
            )
        } else {
            repository = LocalSpotRepository()
        }
        _store = StateObject(wrappedValue: SpotStore(repository: repository))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authStore.isRestoringSession {
                    ProgressView()
                        .tint(PerchTheme.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(PerchTheme.background.ignoresSafeArea())
                } else if authStore.isSignedIn {
                    PerchShell {
                        Group {
                            switch appState.selectedTab {
                            case .explore:
                                ExploreView()
                            case .saved:
                                SavedView()
                            case .addSpot:
                                AddSpotView()
                            }
                        }
                    }
                } else {
                    SignInView()
                }
            }
            .environmentObject(store)
            .environmentObject(favorites)
            .environmentObject(locationManager)
            .environmentObject(appState)
            .environmentObject(profileStore)
            .environmentObject(reviewStore)
            .environmentObject(authStore)
            .task {
                await store.load()
                if appState.hasCompletedOnboarding {
                    locationManager.requestIfNeeded()
                }
            }
            .task(id: authStore.currentUser?.id) {
                guard !authStore.isRestoringSession else { return }
                if authStore.isSignedIn {
                    await store.load()
                } else {
                    store.clearUserSpots()
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { !appState.hasCompletedOnboarding },
                set: { _ in }
            )) {
                OnboardingView()
                    .environmentObject(appState)
                    .environmentObject(locationManager)
            }
        }
    }
}
