import SwiftUI

@main
struct PerchIOSApp: App {
    @StateObject private var store: SpotStore
    @StateObject private var favorites: FavoritesStore
    @StateObject private var locationManager = LocationManager()
    @StateObject private var appState = AppState()
    @StateObject private var profileStore: ProfileStore
    @StateObject private var reviewStore: ReviewStore
    @StateObject private var authStore: AuthStore
    @StateObject private var migrationStore: LocalDataMigrationStore

    init() {
        let authStore = AuthStore()
        _authStore = StateObject(wrappedValue: authStore)

        let spotRepository: SpotRepository
        let favoritesRepository: FavoritesRepository
        let profileRepository: ProfileRepository
        let reviewRepository: ReviewRepository
        let migrationStore: LocalDataMigrationStore
        if let client = SupabaseClientProvider.shared {
            let supabaseSpotRepository = SupabaseSpotRepository(
                client: client,
                currentUserID: { authStore.currentUser?.id }
            )
            let supabaseFavoritesRepository = SupabaseFavoritesRepository(
                client: client,
                currentUserID: { authStore.currentUser?.id }
            )
            let supabaseProfileRepository = SupabaseProfileRepository(
                client: client,
                currentUserID: { authStore.currentUser?.id }
            )
            let supabaseReviewRepository = SupabaseReviewRepository(
                client: client,
                currentUserID: { authStore.currentUser?.id }
            )
            spotRepository = supabaseSpotRepository
            favoritesRepository = supabaseFavoritesRepository
            profileRepository = supabaseProfileRepository
            reviewRepository = supabaseReviewRepository
            migrationStore = LocalDataMigrationStore(
                migrator: LocalToRemoteMigrator(
                    remoteSpotRepository: supabaseSpotRepository,
                    remoteReviewRepository: supabaseReviewRepository,
                    remoteFavoritesRepository: supabaseFavoritesRepository,
                    remoteProfileRepository: supabaseProfileRepository,
                    imageStorage: SupabaseImageStorage(client: client)
                ),
                currentUserID: { authStore.currentUser?.id }
            )
        } else {
            spotRepository = LocalSpotRepository()
            favoritesRepository = LocalFavoritesRepository()
            profileRepository = LocalProfileRepository()
            reviewRepository = LocalReviewRepository()
            migrationStore = LocalDataMigrationStore(
                migrator: nil,
                currentUserID: { authStore.currentUser?.id }
            )
        }
        _store = StateObject(wrappedValue: SpotStore(repository: spotRepository))
        _favorites = StateObject(wrappedValue: FavoritesStore(repository: favoritesRepository))
        _profileStore = StateObject(wrappedValue: ProfileStore(repository: profileRepository))
        _reviewStore = StateObject(wrappedValue: ReviewStore(repository: reviewRepository))
        _migrationStore = StateObject(wrappedValue: migrationStore)
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
            .environmentObject(migrationStore)
            .task {
                await store.load()
                await favorites.load()
                await profileStore.load()
                await reviewStore.load()
                if appState.hasCompletedOnboarding {
                    locationManager.requestIfNeeded()
                }
            }
            .task(id: authStore.currentUser?.id) {
                guard !authStore.isRestoringSession else { return }
                if authStore.isSignedIn {
                    await store.load()
                    await favorites.load()
                    await profileStore.load()
                    await reviewStore.load()
                    await migrationStore.evaluateAfterSignIn()
                } else {
                    store.clearUserSpots()
                    favorites.clear()
                    profileStore.clear()
                    reviewStore.clear()
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
            .sheet(item: $migrationStore.sheetMode) { _ in
                LocalDataMigrationView()
                    .environmentObject(migrationStore)
            }
            .onChange(of: migrationStore.completedRunID) {
                Task {
                    await store.load()
                    await favorites.load()
                    await profileStore.load()
                    await reviewStore.load()
                }
            }
        }
    }
}
