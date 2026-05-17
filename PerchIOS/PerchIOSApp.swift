import SwiftUI

@main
struct PerchIOSApp: App {
    @StateObject private var store = SpotStore()
    @StateObject private var favorites = FavoritesStore()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var appState = AppState()
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var reviewStore = ReviewStore()

    var body: some Scene {
        WindowGroup {
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
            .environmentObject(store)
            .environmentObject(favorites)
            .environmentObject(locationManager)
            .environmentObject(appState)
            .environmentObject(profileStore)
            .environmentObject(reviewStore)
            .task {
                store.load()
                if appState.hasCompletedOnboarding {
                    locationManager.requestIfNeeded()
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
