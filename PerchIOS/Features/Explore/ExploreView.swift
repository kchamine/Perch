import CoreLocation
import MapKit
import SwiftUI

struct ExploreView: View {
    @EnvironmentObject private var store: SpotStore
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var reviewStore: ReviewStore

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showFilters = false
    @State private var showProfile = false
    @State private var searchText = ""
    @State private var sortOption: SpotSortOption = .distance
    @State private var prioritizedSpotID: UUID?
    @State private var revealedSpot: Spot?
    @State private var selectedViewType: ViewType?
    @State private var nearbyRailMinimized = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                mapLayer

                VStack(spacing: 0) {
                    topChrome
                    Spacer()
                }

                if !visibleSpots.isEmpty {
                    VStack {
                        Spacer()
                        nearbyRail
                            .padding(.bottom, 96)
                    }
                }

            }
            .sheet(isPresented: $showFilters) {
                FilterSheetView(filters: $store.filters)
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .navigationDestination(item: $store.selectedSpot) { spot in
                SpotDetailView(
                    spot: spot,
                    location: locationManager.location,
                    isUserSpot: store.isUserSpot(spot)
                )
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                locationManager.requestIfNeeded()
                if !handlePendingReveal() {
                    recenter()
                }
            }
            .onChange(of: locationManager.location) { _, _ in
                recenterIfNeeded()
            }
            .onChange(of: store.filters) { _, _ in
                clearRevealOverride()
            }
            .onChange(of: store.selectedSpot) { _, selectedSpot in
                guard selectedSpot != nil else { return }
                clearRevealOverride(force: true)
            }
            .onChange(of: appState.pendingRevealSpot) { _, _ in
                _ = handlePendingReveal()
            }
        }
    }

    private var mapLayer: some View {
        Map(position: $cameraPosition, selection: $store.selectedSpot) {
            ForEach(visibleSpots) { spot in
                Marker(spot.name, systemImage: favorites.isFavorite(spot) ? "bookmark.fill" : markerSymbol(for: spot), coordinate: spot.coordinate)
                    .tint(markerTint(for: spot))
                    .tag(spot)
            }
            UserAnnotation()
        }
        .mapStyle(.standard(elevation: .realistic))
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) {
            if let error = store.loadError {
                Text(error)
                    .font(.caption)
                    .padding(10)
                    .background(PerchTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(PerchTheme.border, lineWidth: 1)
                    )
                    .padding()
            }
        }
    }

    private var topChrome: some View {
        VStack(spacing: 10) {
            PerchTopBar(
                leadingSystemImage: nil,
                title: "Perch",
                trailingSystemImage: "person.crop.circle",
                onTrailingTap: { showProfile = true }
            )
            .padding(.top, 8)

            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(PerchTheme.primary)
                    TextField("Find a quiet spot...", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($searchFocused)
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(PerchTheme.primary)
                            .frame(width: 34, height: 34)
                            .background(PerchTheme.chipFill, in: Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .perchGlassCard()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        filterChip(title: "All", icon: "sparkles", viewType: nil)
                        filterChip(title: "Parks", icon: "tree", viewType: .park)
                        filterChip(title: "Views", icon: "mountain.2", viewType: .skyline)
                        filterChip(title: "Water", icon: "water.waves", viewType: .water)
                        filterChip(title: "Street", icon: "building.2", viewType: .street)
                    }
                    .padding(.horizontal, 2)
                }

                if nearbyRailMinimized {
                    HStack {
                        Spacer()
                        Button {
                            recenter()
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(PerchTheme.primary)
                                .frame(width: 44, height: 44)
                                .background(PerchTheme.chipFill, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 18)
        }
    }

    private var nearbyRail: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Nearby — \(visibleSpots.count) spot\(visibleSpots.count == 1 ? "" : "s")")
                    .font(PerchTheme.label(11, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(PerchTheme.textMuted)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        nearbyRailMinimized.toggle()
                    }
                } label: {
                    Image(systemName: nearbyRailMinimized ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PerchTheme.primary)
                        .frame(width: 30, height: 30)
                        .background(PerchTheme.chipFill, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)

            if !nearbyRailMinimized {
                HStack(spacing: 10) {
                    Menu {
                        Picker("Sort spots", selection: $sortOption) {
                            ForEach(SpotSortOption.allCases) { option in
                                Label(option.label, systemImage: option.systemImage)
                                    .tag(option)
                            }
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: sortOption.systemImage)
                            Text(sortOption.label)
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .font(PerchTheme.label(10, weight: .bold))
                        .foregroundStyle(PerchTheme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(PerchTheme.controlFill, in: Capsule())
                        .overlay(
                            Capsule().stroke(PerchTheme.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Text(sortDescription)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PerchTheme.textMuted)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(visibleSpots.prefix(12)) { spot in
                            Button { store.selectedSpot = spot } label: {
                                nearbyCard(for: spot)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, 18)
                    .padding(.trailing, 18)
                    .padding(.bottom, 12)
                }
            }
        }
        .background(PerchTheme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(PerchTheme.border, lineWidth: 1)
        )
    }

    private func nearbyCard(for spot: Spot) -> some View {
        HStack(spacing: 12) {
            SeedOrUserPhotoView(spot: spot, style: .photoOnly)
                .frame(width: 58, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(store.isUserSpot(spot) ? "Yours" : spot.viewType.label)
                        .font(PerchTheme.label(8, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(PerchTheme.accent.opacity(0.8), in: Capsule())
                        .foregroundStyle(PerchTheme.primary)

                    Spacer(minLength: 0)

                    if favorites.isFavorite(spot) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(PerchTheme.primary)
                    }
                }
                .frame(height: 20)

                Text(spot.name)
                    .font(PerchTheme.headline(16))
                    .foregroundStyle(PerchTheme.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)

                HStack(spacing: 8) {
                    Label(distanceText(for: spot), systemImage: "location")
                    Label(nearbyRatingText(for: spot), systemImage: "star.fill")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(PerchTheme.textMuted)
                .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)

                Text(compactTrustLine(for: spot))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PerchTheme.textMuted)
                    .lineLimit(1)
            }
            .frame(width: 148)
            .frame(minHeight: 76)
        }
        .padding(10)
        .frame(width: 238)
        .perchGlassCard()
    }

    private func filterChip(title: String, icon: String, viewType: ViewType?) -> some View {
        let isActive = selectedViewType == viewType
        return Button {
            selectedViewType = viewType
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(PerchTheme.label(11, weight: .bold))
            .textCase(.uppercase)
            .tracking(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isActive ? PerchTheme.controlFillStrong : PerchTheme.controlFill, in: Capsule())
            .overlay(
                Capsule().stroke(isActive ? PerchTheme.primarySoft.opacity(0.75) : PerchTheme.border, lineWidth: 1)
            )
            .foregroundStyle(isActive ? PerchTheme.controlTextOnStrong : PerchTheme.primary)
        }
        .buttonStyle(.plain)
    }

    private var filteredSpots: [Spot] {
        let base = store.filteredSpots(location: locationManager.location, favorites: favorites.favoriteIDs)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let typed = selectedViewType == nil ? base : base.filter { $0.viewType == selectedViewType }

        guard !query.isEmpty else { return sort(typed) }

        return sort(typed.filter { spot in
            let haystacks = [
                spot.name,
                spot.subtitle,
                spot.notes,
                spot.viewType.label,
                spot.bestTime.label,
                spot.spotType.label,
                spot.seatingType.label
            ]
            return haystacks.contains { $0.localizedCaseInsensitiveContains(query) }
        })
    }

    private var visibleSpots: [Spot] {
        var spots = filteredSpots

        if let revealedSpot, !spots.contains(where: { $0.id == revealedSpot.id }) {
            spots.insert(revealedSpot, at: 0)
        }

        guard let prioritizedSpotID,
              let prioritizedSpot = spots.first(where: { $0.id == prioritizedSpotID }) else {
            return spots
        }

        return [prioritizedSpot] + spots.filter { $0.id != prioritizedSpotID }
    }

    private func nearbyRatingText(for spot: Spot) -> String {
        let summary = reviewStore.summary(for: spot.id)
        let value = summary.count > 0 ? summary.averageOverall : Double(spot.scenicRating)
        return String(format: "%.1f", value)
    }

    private func compactTrustLine(for spot: Spot) -> String {
        let summary = reviewStore.summary(for: spot.id)
        if let returnSignal = summary.returnSignalText {
            return returnSignal
        }
        if summary.count > 0 {
            return summary.trustHeadline(fallback: spot)
        }
        return spot.practicalCaveat
    }

    private func markerSymbol(for spot: Spot) -> String {
        spot.spotType.icon
    }

    private func markerTint(for spot: Spot) -> Color {
        if favorites.isFavorite(spot) { return PerchTheme.primary }
        switch spot.viewType {
        case .water: return .blue
        case .skyline: return .indigo
        case .park: return .green
        case .hill: return .orange
        case .street: return .gray
        case .mixed: return .teal
        }
    }

    private var sortDescription: String {
        switch sortOption {
        case .distance:
            return locationManager.location == nil ? "Sorting A–Z until location is available." : "Closest dependable perches first."
        case .scenic:
            return "Uses local review score first, then scenic backup."
        case .comfort:
            return "Find easier stay-a-while spots first."
        case .name:
            return "Alphabetical browse."
        case .recentlyConfirmed:
            return "Freshly confirmed spots first."
        }
    }

    private func sort(_ spots: [Spot]) -> [Spot] {
        switch sortOption {
        case .distance:
            guard let location = locationManager.location else {
                return spots.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
            return spots.sorted { lhs, rhs in
                lhs.distance(from: location) < rhs.distance(from: location)
            }
        case .scenic:
            return spots.sorted { lhs, rhs in
                let lhsSummary = reviewStore.summary(for: lhs.id)
                let rhsSummary = reviewStore.summary(for: rhs.id)
                let lhsScore = lhsSummary.count > 0 ? lhsSummary.averageOverall : Double(lhs.scenicRating)
                let rhsScore = rhsSummary.count > 0 ? rhsSummary.averageOverall : Double(rhs.scenicRating)
                if lhsScore == rhsScore {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhsScore > rhsScore
            }
        case .comfort:
            return spots.sorted { lhs, rhs in
                let lhsSummary = reviewStore.summary(for: lhs.id)
                let rhsSummary = reviewStore.summary(for: rhs.id)
                let lhsScore = lhsSummary.count > 0 ? lhsSummary.averageStayComfort : Double(lhs.comfortRating)
                let rhsScore = rhsSummary.count > 0 ? rhsSummary.averageStayComfort : Double(rhs.comfortRating)
                if lhsScore == rhsScore {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhsScore > rhsScore
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

    private func recenter() {
        if let location = locationManager.location {
            cameraPosition = .region(MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            ))
        } else if let first = store.allSpots.first(where: { !$0.isPrivate }) {
            cameraPosition = .region(MKCoordinateRegion(
                center: first.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
            ))
        }
    }

    @discardableResult
    private func handlePendingReveal() -> Bool {
        guard let spot = appState.pendingRevealSpot else { return false }

        store.selectedSpot = nil
        revealedSpot = spot
        prioritizedSpotID = spot.id
        cameraPosition = .region(MKCoordinateRegion(
            center: spot.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        ))
        appState.markRevealHandled(for: spot)
        return true
    }

    private func recenterIfNeeded() {
        if case .automatic = cameraPosition {
            recenter()
        }
    }

    private func clearRevealOverride(force: Bool = false) {
        revealedSpot = nil
        if force || store.selectedSpot == nil {
            prioritizedSpotID = nil
        }
    }

    private func distanceText(for spot: Spot) -> String {
        let meters = spot.distance(from: locationManager.location)
        guard meters.isFinite else { return "—" }
        if meters < 1000 { return "\(Int(meters)) m" }
        return String(format: "%.1f km", meters / 1000)
    }
}
