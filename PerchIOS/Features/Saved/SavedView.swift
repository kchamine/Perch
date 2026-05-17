import CoreLocation
import SwiftUI

struct SavedView: View {
    @EnvironmentObject private var store: SpotStore
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var locationManager: LocationManager

    @State private var searchText = ""
    @State private var sortOption: SpotSortOption = .recentlyConfirmed
    @State private var showProfile = false
    @State private var spotToEdit: Spot?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PerchTopBar(
                        leadingSystemImage: nil,
                        title: "Perch",
                        trailingSystemImage: "person.crop.circle",
                        onTrailingTap: { showProfile = true }
                    )
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Collection")
                            .font(PerchTheme.label(10, weight: .bold))
                            .textCase(.uppercase)
                            .tracking(1.1)
                            .foregroundStyle(.secondary)
                        Text("Saved Spaces")
                            .font(PerchTheme.headline(44))
                            .foregroundStyle(PerchTheme.primary)
                    }
                    .padding(.horizontal, 18)

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(PerchTheme.primary)
                        TextField("Search favorites and my spots", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Menu {
                            Picker("Sort", selection: $sortOption) {
                                ForEach(SpotSortOption.allCases.filter { $0 != .distance }) { option in
                                    Text(option.label).tag(option)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundStyle(PerchTheme.primary)
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.55), in: Circle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .perchGlassCard()
                    .padding(.horizontal, 18)

                    if favoriteSpots.isEmpty && userSpots.isEmpty {
                        emptyState
                    } else {
                        if !favoriteSpots.isEmpty {
                            sectionHeader("Favorites")
                            ForEach(favoriteSpots) { spot in
                                savedCard(for: spot, showDelete: store.isUserSpot(spot))
                            }
                        }

                        if !userSpots.isEmpty {
                            sectionHeader("My spots")
                            ForEach(userSpots) { spot in
                                savedCard(for: spot, showDelete: true)
                            }
                        }
                    }
                }
                .padding(.bottom, 120)
            }
            .background(PerchTheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .sheet(item: $spotToEdit) { spot in
                AddSpotView(editingSpot: spot)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 12) {
            Text("Curate your next chapter")
                .font(PerchTheme.headline(30))
                .foregroundStyle(PerchTheme.primary.opacity(0.55))
            Text("Heart a spot from Explore or add your own and it will show up here for quick re-use.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(PerchTheme.headline(26))
            .foregroundStyle(PerchTheme.primary)
            .padding(.horizontal, 20)
            .padding(.top, 8)
    }

    private func savedCard(for spot: Spot, showDelete: Bool) -> some View {
        NavigationLink {
            SpotDetailView(
                spot: spot,
                location: locationManager.location,
                isUserSpot: store.isUserSpot(spot)
            )
        } label: {
            ZStack(alignment: .bottomLeading) {
                SeedOrUserPhotoView(spot: spot, style: .photoOnly)
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .overlay {
                        LinearGradient(colors: [.clear, .black.opacity(0.34)], startPoint: .center, endPoint: .bottom)
                            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    }

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(spot.name)
                            .font(PerchTheme.headline(30))
                            .foregroundStyle(Color.white)
                            .lineLimit(2)
                        HStack(spacing: 8) {
                            InlineTag(text: spot.viewType.label, tint: .white)
                            InlineTag(text: spot.bestTime.label, tint: .white)
                            if spot.isPrivate {
                                InlineTag(icon: "lock.fill", text: "Private", tint: .white)
                            }
                        }
                    }
                    Spacer(minLength: 12)
                    if showDelete {
                        HStack(spacing: 8) {
                            Button {
                                spotToEdit = spot
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(PerchTheme.iconOnLightControl)
                                    .padding(14)
                                    .background(Color.white.opacity(0.92), in: Circle())
                            }
                            .buttonStyle(.plain)

                            Button(role: .destructive) {
                                deleteSpot(spot)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(PerchTheme.iconOnLightControl)
                                    .padding(14)
                                    .background(Color.white.opacity(0.92), in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(PerchTheme.iconOnLightControl)
                            .padding(14)
                            .background(Color.white.opacity(0.92), in: Circle())
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                )
            }
            .shadow(color: Color.black.opacity(0.08), radius: 16, y: 8)
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }

    private var favoriteSpots: [Spot] {
        sorted(store.allSpots.filter { favorites.favoriteIDs.contains($0.id) && matchesSearch($0) })
    }

    private var userSpots: [Spot] {
        sorted(store.userSpots.filter { !favorites.favoriteIDs.contains($0.id) && matchesSearch($0) })
    }

    private func matchesSearch(_ spot: Spot) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return [spot.name, spot.subtitle, spot.notes, spot.viewType.label, spot.bestTime.label]
            .contains { $0.localizedCaseInsensitiveContains(query) }
    }

    private func sorted(_ spots: [Spot]) -> [Spot] {
        switch sortOption {
        case .distance:
            return spots
        case .scenic:
            return spots.sorted { lhs, rhs in
                if lhs.scenicRating == rhs.scenicRating {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.scenicRating > rhs.scenicRating
            }
        case .comfort:
            return spots.sorted { lhs, rhs in
                if lhs.comfortRating == rhs.comfortRating {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.comfortRating > rhs.comfortRating
            }
        case .name:
            return spots.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .recentlyConfirmed:
            return spots.sorted { lhs, rhs in
                if lhs.lastConfirmed == rhs.lastConfirmed {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.lastConfirmed > rhs.lastConfirmed
            }
        }
    }

    private func deleteSpot(_ spot: Spot) {
        store.deleteUserSpots(ids: Set([spot.id]))
        favorites.remove(Set([spot.id]))
    }
}
