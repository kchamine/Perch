import CoreLocation
import PhotosUI
import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var store: SpotStore
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var reviewStore: ReviewStore
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var migrationStore: LocalDataMigrationStore
    @Environment(\.dismiss) private var dismiss

    @State private var profile: UserProfile = .default
    @State private var isShowingEditProfile = false
    @State private var pendingDeletionID: UUID?
    @State private var isConfirmingSignOut = false
    @State private var isSigningOut = false
    @State private var signOutError: String?

    private var displayName: String {
        let trimmed = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Local Perch Keeper" : trimmed
    }

    private var handleLine: String {
        "@\(UserProfile.sanitizedHandle(profile.username))"
    }

    private var joinedLine: String {
        "On this device since \(profile.joinedAt.formatted(date: .abbreviated, time: .omitted))"
    }

    private var savedSpots: [Spot] {
        store.allSpots.filter { favorites.favoriteIDs.contains($0.id) }
    }

    private var recentAddedSpots: [Spot] {
        store.userSpots.sorted(by: recentFirst)
    }

    private var recentReviews: [SpotReview] {
        reviewStore.reviews.sorted { $0.createdAt > $1.createdAt }
    }

    private var reviewedSpotIDs: Set<UUID> {
        Set(reviewStore.reviews.map(\.spotID))
    }

    private var reviewedSpotCount: Int {
        reviewedSpotIDs.count
    }

    private var averageReviewScore: Double {
        guard !reviewStore.reviews.isEmpty else { return 0 }
        return reviewStore.reviews.map(\.overallRating).reduce(0, +) / Double(reviewStore.reviews.count)
    }

    private var topMoments: [PerchReviewMoment] {
        Array(
            Dictionary(grouping: reviewStore.reviews.flatMap(\.bestFor), by: \.self)
                .sorted { lhs, rhs in
                    if lhs.value.count == rhs.value.count {
                        return lhs.key.label < rhs.key.label
                    }
                    return lhs.value.count > rhs.value.count
                }
                .prefix(3)
                .map(\.key)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    headerCard
                    profileSnapshotCard
                    activityOverviewCard
                    identitySection
                    activitySection
                    accountSection
                    settingsSection
                    aboutSection
                }
                .padding(20)
                .padding(.bottom, 32)
            }
            .background(PerchTheme.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PerchTheme.primary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit Profile") {
                        isShowingEditProfile = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PerchTheme.primary)
                }
            }
            .task {
                refreshProfileFromStore()
            }
            .alert("Delete review?", isPresented: Binding(
                get: { pendingDeletionID != nil },
                set: { if !$0 { pendingDeletionID = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let id = pendingDeletionID {
                        reviewStore.deleteReview(id: id)
                    }
                    pendingDeletionID = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDeletionID = nil
                }
            } message: {
                Text("This review will be permanently removed.")
            }
            .alert("Sign out?", isPresented: $isConfirmingSignOut) {
                Button("Sign out", role: .destructive) {
                    signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Perch will return to the sign-in screen.")
            }
            .sheet(isPresented: $isShowingEditProfile) {
                EditProfileView(
                    startingProfile: profileStore.profile,
                    onSave: { updatedProfile in
                        profileStore.update { saved in
                            saved = updatedProfile.normalized
                        }
                        profile = profileStore.profile
                    }
                )
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                avatarView(size: 90)

                VStack(alignment: .leading, spacing: 8) {
                    Text(displayName)
                        .font(PerchTheme.headline(30))
                        .foregroundStyle(PerchTheme.primary)
                    Text(handleLine)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PerchTheme.primarySoft)
                    if !profile.homeNeighborhood.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Label(profile.homeNeighborhood, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(PerchTheme.textMuted)
                    }
                    Text(joinedLine)
                        .font(PerchTheme.label(10, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(PerchTheme.textMuted)
                }

                Spacer(minLength: 0)
            }

            Text(trimmed(profile.bio, fallback: UserProfile.default.bio))
                .font(.subheadline)
                .foregroundStyle(PerchTheme.textMuted)
                .lineSpacing(3)

            TagFlowLayout(spacing: 8, rowSpacing: 8) {
                InlineTag(icon: "sparkles", text: trimmed(profile.favoriteMoment, fallback: UserProfile.default.favoriteMoment), tint: PerchTheme.primary)
                InlineTag(icon: "leaf", text: trimmed(profile.perchStyle, fallback: UserProfile.default.perchStyle), tint: PerchTheme.primarySoft)
                InlineTag(icon: "arrow.triangle.2.circlepath", text: "Synced account", tint: PerchTheme.textMuted)
            }

            if let loadError = profileStore.loadError {
                Text(loadError)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PerchTheme.controlFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            HStack(spacing: 10) {
                statPill(title: "Added", value: "\(store.userSpots.count)")
                statPill(title: "Saved", value: "\(favorites.favoriteIDs.count)")
                statPill(title: "Reviews", value: "\(reviewStore.reviews.count)")
                statPill(title: "Places rated", value: "\(reviewedSpotCount)")
            }
        }
        .padding(20)
        .perchGlassCard()
    }

    private var profileSnapshotCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                sectionTitle("Profile snapshot")
                Spacer()
                Button {
                    isShowingEditProfile = true
                } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(PerchTheme.primary)
            }

            HStack(spacing: 12) {
                overviewTile(
                    title: "Average review",
                    value: reviewStore.reviews.isEmpty ? "—" : String(format: "%.1f/5", averageReviewScore),
                    subtitle: reviewStore.reviews.isEmpty ? "No reviews yet" : "Across synced reviews"
                )
                overviewTile(
                    title: "Recent activity",
                    value: lastContributionLabel,
                    subtitle: contributionStreakLabel
                )
            }

            if !topMoments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Most common reasons you review spots")
                        .font(PerchTheme.label(10, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(PerchTheme.textMuted)
                    TagFlowLayout(spacing: 8, rowSpacing: 8) {
                        ForEach(topMoments) { moment in
                            InlineTag(icon: "checkmark.circle.fill", text: moment.label, tint: PerchTheme.primary)
                        }
                    }
                }
            }
        }
        .padding(20)
        .perchGlassCard()
    }

    private var activityOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("What lives here")
            Text("Perch now syncs profile details, saved places, reviews, and added spots through your Supabase-backed account.")
                .font(.subheadline)
                .foregroundStyle(PerchTheme.textMuted)
                .lineSpacing(3)

            VStack(spacing: 10) {
                infoRow(icon: "person.text.rectangle", title: "Identity", detail: "Name, handle, bio, home area, and perch taste sync from the dedicated Edit Profile screen.")
                infoRow(icon: "photo", title: "Avatar", detail: "Pick a photo that uploads to Storage, or keep a simple perch icon.")
                infoRow(icon: "square.and.arrow.down", title: "Activity", detail: "Added spots, saved places, and reviews reflect synced account data.")
            }
        }
        .padding(20)
        .perchGlassCard()
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Identity")

            readOnlyField("Display name", value: displayName)
            readOnlyField("Handle", value: handleLine)
            readOnlyField("Home area", value: trimmed(profile.homeNeighborhood, fallback: "Add your area from Edit Profile"))
            readOnlyField("Bio", value: trimmed(profile.bio, fallback: UserProfile.default.bio), multiline: true)
            readOnlyField("Perch style", value: trimmed(profile.perchStyle, fallback: UserProfile.default.perchStyle), multiline: true)
            readOnlyField("Favorite moment", value: trimmed(profile.favoriteMoment, fallback: UserProfile.default.favoriteMoment), multiline: true)
        }
        .padding(20)
        .perchGlassCard()
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Activity & collections")

            contributionBlock(title: "Your spots", subtitle: store.userSpots.isEmpty ? "Nothing posted yet" : "Latest places you’ve added") {
                if recentAddedSpots.isEmpty {
                    emptyState("You haven’t added any spots yet. When you publish one, it’ll show up here for quick revisits.")
                } else {
                    ForEach(recentAddedSpots.prefix(3)) { spot in
                        spotRow(spot: spot, trailingText: reviewCountText(for: spot.id))
                    }
                }
            }

            contributionBlock(title: "Recent reviews", subtitle: reviewStore.reviews.isEmpty ? "No reviews yet" : "Your latest opinions and notes") {
                if recentReviews.isEmpty {
                    emptyState("Once you leave reviews, the latest ones will appear here with the place and rating.")
                } else {
                    ForEach(recentReviews.prefix(3)) { review in
                        reviewRow(review)
                    }
                }
            }

            contributionBlock(title: "Saved collection", subtitle: savedSpots.isEmpty ? "Nothing saved yet" : "Quick access to spots you bookmarked") {
                if savedSpots.isEmpty {
                    emptyState("Your saved spots count is real, but you haven’t bookmarked any places yet.")
                } else {
                    ForEach(savedSpots.prefix(3)) { spot in
                        spotRow(spot: spot, trailingText: favorites.favoriteIDs.contains(spot.id) ? "Saved" : "")
                    }
                }
            }
        }
        .padding(20)
        .perchGlassCard()
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Settings")

            settingsGroup(title: "Review identity & contribution preferences", subtitle: "Control how your synced profile appears when you add places and reviews") {
                infoRow(icon: "person.crop.square", title: "Review display", detail: profile.defaultReviewName.label)
                infoRow(icon: "envelope", title: "Contact email (optional)", detail: trimmed(profile.email, fallback: "Not set"))
                Text("This email is never used for sign-in, passwords, or account recovery in the current build.")
                    .font(.caption)
                    .foregroundStyle(PerchTheme.textMuted)
            }

            settingsGroup(title: "Directions", subtitle: "Choose which maps app Perch opens for spot directions") {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Preferred Maps App", systemImage: "map")
                        .font(.headline)
                        .foregroundStyle(PerchTheme.primary)
                    Picker("Preferred Maps App", selection: mapsAppPreferenceBinding) {
                        ForEach(MapsAppPreference.allCases) { preference in
                            Text(preference.label).tag(preference)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            settingsGroup(title: "Data & privacy", subtitle: "Truthful controls for what syncs with your account today") {
                infoRow(icon: "arrow.triangle.2.circlepath", title: "Account sync active", detail: "Your profile, added spots, saved places, reviews, and custom photos are backed by Supabase.")
                infoRow(icon: "lock.open", title: "No device lock yet", detail: "Perch does not currently add password or biometric protection on top of local storage.")
                infoRow(icon: "person.crop.circle.badge.checkmark", title: "Owner-scoped data", detail: "Synced records are tied to the signed-in Perch account.")
                if migrationStore.isAvailable {
                    Button {
                        Task { await migrationStore.presentManualSync() }
                    } label: {
                        Label("Sync local data now", systemImage: "icloud.and.arrow.up")
                            .font(.headline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(PerchTheme.primary)

                    if let statusMessage = migrationStore.statusMessage {
                        Text(statusMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PerchTheme.textMuted)
                    }
                }
            }

            settingsGroup(title: "About & sync status", subtitle: "What this profile experience is designed to be in Perch 1.0") {
                infoRow(icon: "person.text.rectangle", title: "A real profile", detail: "This surface tracks identity, taste, and activity from the signed-in account.")
                infoRow(icon: "sparkles", title: "Contribution-first", detail: "Your added spots, saved places, and reviews drive the profile stats and activity sections above.")
                infoRow(icon: "shippingbox", title: "Backend-backed shape", detail: "The structure maps directly into Supabase auth, database rows, and Storage assets.")
            }
        }
        .padding(20)
        .perchGlassCard()
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Account")

            settingsGroup(title: "Perch account", subtitle: "Your identity for backend-backed sync and ownership") {
                infoRow(icon: "person.crop.circle.badge.checkmark", title: "Signed in", detail: authStore.currentUser?.email ?? "Perch account")

                if let signOutError {
                    Text(signOutError)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                }

                Button(role: .destructive) {
                    isConfirmingSignOut = true
                } label: {
                    HStack {
                        if isSigningOut {
                            ProgressView()
                        }
                        Label(isSigningOut ? "Signing out..." : "Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(isSigningOut)
            }
        }
        .padding(20)
        .perchGlassCard()
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("About this profile")
            infoRow(icon: "arrow.triangle.2.circlepath", title: "Synced with your account", detail: "Perch saves this profile through the backend when you are signed in.")
            infoRow(icon: "person.crop.circle.badge.checkmark", title: "Built around your real usage", detail: "Profile stats and collections come from the spots you add, save, and review in the app.")
            infoRow(icon: "shippingbox", title: "Backend-backed", detail: "Profile, favorite, review, spot, and photo data now use the Supabase implementation.")
        }
        .padding(20)
        .perchGlassCard()
    }

    private var lastContributionLabel: String {
        let latestSpot = store.userSpots.map(\.lastConfirmed).max()
        let latestReview = reviewStore.reviews.map(\.createdAt).max()
        guard let latest = [latestSpot, latestReview].compactMap({ $0 }).max() else { return "Just getting started" }
        return latest.formatted(date: .abbreviated, time: .omitted)
    }

    private var contributionStreakLabel: String {
        if reviewStore.reviews.count + store.userSpots.count == 0 {
            return "Add a spot or review to build your profile"
        }
        return "\(store.userSpots.count) spots shared • \(reviewStore.reviews.count) reviews written"
    }

    private var mapsAppPreferenceBinding: Binding<MapsAppPreference> {
        Binding(
            get: { profileStore.profile.mapsAppPreference },
            set: { preference in
                profileStore.update { saved in
                    saved.mapsAppPreference = preference
                }
                profile = profileStore.profile
            }
        )
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(PerchTheme.headline(24))
            .foregroundStyle(PerchTheme.primary)
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(PerchTheme.primary)
            Text(title)
                .font(PerchTheme.label(9, weight: .bold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(PerchTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(PerchTheme.controlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PerchTheme.border, lineWidth: 1)
        )
    }

    private func overviewTile(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(PerchTheme.label(10, weight: .bold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(PerchTheme.textMuted)
            Text(value)
                .font(PerchTheme.headline(22))
                .foregroundStyle(PerchTheme.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(PerchTheme.textMuted)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(PerchTheme.controlFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(PerchTheme.border, lineWidth: 1)
        )
    }

    private func infoRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PerchTheme.primary)
                .frame(width: 30, height: 30)
                .background(PerchTheme.chipFill, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(PerchTheme.primary)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(PerchTheme.textMuted)
            }
            Spacer(minLength: 0)
        }
    }

    private func contributionBlock<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(PerchTheme.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(PerchTheme.textMuted)
            }
            content()
        }
        .padding(16)
        .background(PerchTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func settingsGroup<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(PerchTheme.primary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(PerchTheme.textMuted)
            content()
        }
        .padding(16)
        .background(PerchTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(PerchTheme.textMuted)
    }

    private func readOnlyField(_ label: String, value: String, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(PerchTheme.label(10, weight: .bold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(PerchTheme.textMuted)

            Text(value)
                .font(.body)
                .foregroundStyle(PerchTheme.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: multiline)
                .padding(14)
                .background(PerchTheme.controlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PerchTheme.border, lineWidth: 1)
                )
        }
    }

    private func spotRow(spot: Spot, trailingText: String) -> some View {
        NavigationLink {
            SpotDetailView(
                spot: spot,
                location: CLLocation(latitude: spot.latitude, longitude: spot.longitude),
                isUserSpot: store.isUserSpot(spot)
            )
        } label: {
            HStack(spacing: 12) {
                SeedOrUserPhotoView(spot: spot, style: .photoOnly)
                    .frame(width: 70, height: 82)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(spot.name)
                        .font(.headline)
                        .foregroundStyle(PerchTheme.primary)
                        .lineLimit(1)
                    Text(spot.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(PerchTheme.textMuted)
                        .lineLimit(2)
                    TagFlowLayout(spacing: 8, rowSpacing: 8) {
                        InlineTag(text: spot.bestTime.label, tint: PerchTheme.textMuted)
                        InlineTag(text: spot.viewType.label, tint: PerchTheme.primary)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 8) {
                    if !trailingText.isEmpty {
                        Text(trailingText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PerchTheme.textMuted)
                    }
                    Image(systemName: "chevron.right")
                        .foregroundStyle(PerchTheme.textMuted)
                }
            }
            .padding(14)
            .background(PerchTheme.controlFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(PerchTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func reviewRow(_ review: SpotReview) -> some View {
        let spot = store.allSpots.first(where: { $0.id == review.spotID })

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(review.title)
                        .font(.headline)
                        .foregroundStyle(PerchTheme.primary)
                    Text(spot?.name ?? "Unknown spot")
                        .font(.subheadline)
                        .foregroundStyle(PerchTheme.textMuted)
                }
                Spacer()
                Text(String(format: "%.1f", review.overallRating))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PerchTheme.primary)
                Button {
                    pendingDeletionID = review.id
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(PerchTheme.controlFill, in: Circle())
                }
                .buttonStyle(.plain)
            }

            if !review.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(review.note)
                    .font(.subheadline)
                    .foregroundStyle(PerchTheme.textMuted)
                    .lineLimit(3)
            }

            TagFlowLayout(spacing: 8, rowSpacing: 8) {
                InlineTag(text: review.wouldReturn ? "Would return" : "One-time stop", tint: review.wouldReturn ? .green : .orange)
                ForEach(review.bestFor.prefix(2)) { moment in
                    InlineTag(text: moment.label, tint: PerchTheme.primary)
                }
            }
        }
        .padding(14)
        .background(PerchTheme.controlFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(PerchTheme.border, lineWidth: 1)
        )
    }

    private func avatarView(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(PerchTheme.accent)
                .frame(width: size, height: size)

            if let avatarURL = URL(string: profile.avatarURL), profile.hasCustomAvatar {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        ProgressView()
                            .tint(PerchTheme.primary)
                    case .failure:
                        Image(systemName: profile.avatarSymbol)
                            .font(.system(size: size * 0.42, weight: .semibold))
                            .foregroundStyle(PerchTheme.primary)
                    @unknown default:
                        ProgressView()
                            .tint(PerchTheme.primary)
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                Image(systemName: profile.avatarSymbol)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(PerchTheme.primary)
            }
        }
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        )
    }

    private func refreshProfileFromStore() {
        profile = profileStore.profile
    }

    private func reviewCountText(for spotID: UUID) -> String {
        let count = reviewStore.reviews(for: spotID).count
        return count == 1 ? "1 review" : "\(count) reviews"
    }

    private func trimmed(_ value: String, fallback: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? fallback : clean
    }

    private func recentFirst(lhs: Spot, rhs: Spot) -> Bool {
        lhs.lastConfirmed > rhs.lastConfirmed
    }

    private func signOut() {
        isSigningOut = true
        signOutError = nil

        Task {
            do {
                try await authStore.signOut()
                dismiss()
            } catch {
                signOutError = PerchAuthError.map(error).localizedDescription
            }
            isSigningOut = false
        }
    }
}

private struct EditProfileView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: UserProfile
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var pendingAvatarImage: UIImage?
    @State private var isLoadingAvatar = false
    @State private var isSavingProfile = false
    @State private var isUsingIconAvatar = false
    @State private var avatarError: String?
    @State private var activeLongField: EditProfileLongField?

    private let imageStorage: ImageStorageProviding?
    private let originalAvatarURL: String
    private let onSave: (UserProfile) -> Void
    private let avatarSymbols = [
        "leaf.circle.fill",
        "binoculars.fill",
        "sun.max.fill",
        "moon.stars.fill",
        "figure.seated.side",
        "camera.macro.circle.fill"
    ]

    init(
        startingProfile: UserProfile,
        imageStorage: ImageStorageProviding? = SupabaseImageStorage.shared,
        onSave: @escaping (UserProfile) -> Void
    ) {
        _draft = State(initialValue: startingProfile)
        _isUsingIconAvatar = State(initialValue: !startingProfile.hasCustomAvatar)
        self.imageStorage = imageStorage
        self.originalAvatarURL = startingProfile.avatarURL
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile preview") {
                    HStack(spacing: 14) {
                        avatarView(size: 72)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName)
                                .font(.headline)
                            Text("@\(UserProfile.sanitizedHandle(draft.username))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if !draft.homeNeighborhood.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(draft.homeNeighborhood)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Avatar") {
                    PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                        Label(isLoadingAvatar ? "Loading photo..." : "Choose photo", systemImage: "photo.badge.plus")
                    }
                    .disabled(isSavingProfile)

                    if !isUsingIconAvatar || pendingAvatarImage != nil {
                        Button("Use icon instead", role: .destructive) {
                            pendingAvatarImage = nil
                            avatarImage = nil
                            isUsingIconAvatar = true
                            avatarError = nil
                        }
                        .disabled(isSavingProfile)
                    }

                    Picker("Icon", selection: $draft.avatarSymbol) {
                        ForEach(avatarSymbols, id: \.self) { symbol in
                            Label(symbolLabel(for: symbol), systemImage: symbol).tag(symbol)
                        }
                    }

                    Text(avatarStatusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let avatarError {
                        Text(avatarError)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                }

                Section("Identity") {
                    TextField("Display name", text: $draft.displayName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()

                    TextField("Handle", text: handleBinding)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)

                    TextField("Home area", text: $draft.homeNeighborhood)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }

                Section("Longer profile details") {
                    longTextRow(for: .bio)
                    longTextRow(for: .perchStyle)
                    longTextRow(for: .favoriteMoment)

                    Text("Longer notes now open one at a time in a dedicated editor to keep profile editing simpler on-device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Review identity") {
                    Picker("Review display", selection: $draft.defaultReviewName) {
                        ForEach(ReviewDisplayNameMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    TextField("Contact email (optional)", text: $draft.email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)

                    Text("This email is profile reference data only. Supabase Auth manages sign-in, passwords, and account recovery.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Sync status") {
                    Text("Profile edits sync to your signed-in Perch account. Local pre-account data can be moved from the Profile data controls.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSavingProfile)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task { await saveProfile() }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSavingProfile)
                }
            }
            .interactiveDismissDisabled(isLoadingAvatar || isSavingProfile)
            .sheet(item: $activeLongField) { field in
                LongTextEditorView(
                    title: field.title,
                    prompt: field.prompt,
                    text: binding(for: field),
                    placeholder: field.placeholder
                )
            }
            .onChange(of: avatarPickerItem) { _, newValue in
                guard let newValue else { return }
                Task { await importAvatar(from: newValue) }
            }
        }
    }

    private var displayName: String {
        let trimmed = draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Local Perch Keeper" : trimmed
    }

    private var avatarStatusText: String {
        if pendingAvatarImage != nil {
            return "The new photo uploads and replaces your saved avatar when you tap Save."
        }
        if isUsingIconAvatar {
            return "You’re currently using an icon avatar. Choosing a photo keeps it in draft until Save."
        }
        return "Your current saved avatar stays in place unless you save a new photo or switch back to an icon."
    }

    private var handleBinding: Binding<String> {
        Binding(
            get: { draft.username },
            set: { draft.username = UserProfile.sanitizedHandle($0) }
        )
    }

    private func binding(for field: EditProfileLongField) -> Binding<String> {
        Binding(
            get: {
                switch field {
                case .bio: return draft.bio
                case .perchStyle: return draft.perchStyle
                case .favoriteMoment: return draft.favoriteMoment
                }
            },
            set: { newValue in
                switch field {
                case .bio: draft.bio = newValue
                case .perchStyle: draft.perchStyle = newValue
                case .favoriteMoment: draft.favoriteMoment = newValue
                }
            }
        )
    }

    @ViewBuilder
    private func longTextRow(for field: EditProfileLongField) -> some View {
        Button {
            activeLongField = field
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(field.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.primary)
                    Text(previewText(for: field))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func previewText(for field: EditProfileLongField) -> String {
        let text: String
        switch field {
        case .bio: text = draft.bio
        case .perchStyle: text = draft.perchStyle
        case .favoriteMoment: text = draft.favoriteMoment
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? field.placeholder : trimmed
    }

    private func avatarView(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(PerchTheme.accent)
                .frame(width: size, height: size)

            if let avatarImage {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let avatarURL = URL(string: draft.avatarURL), draft.hasCustomAvatar, !isUsingIconAvatar {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        ProgressView()
                    case .failure:
                        Image(systemName: draft.avatarSymbol)
                            .font(.system(size: size * 0.42, weight: .semibold))
                            .foregroundStyle(PerchTheme.primary)
                    @unknown default:
                        ProgressView()
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                Image(systemName: draft.avatarSymbol)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(PerchTheme.primary)
            }

            if isLoadingAvatar {
                ProgressView()
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
            }

            if isSavingProfile {
                ProgressView()
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }

    @MainActor
    private func saveProfile() async {
        guard !isSavingProfile else { return }

        isSavingProfile = true
        avatarError = nil
        defer { isSavingProfile = false }

        var savedProfile = draft.normalized
        savedProfile.updatedAt = .now

        do {
            if let pendingAvatarImage {
                guard let userID = authStore.currentUser?.id else {
                    throw SupabaseImageStorageError.unauthenticated
                }
                guard let data = pendingAvatarImage.jpegData(compressionQuality: 0.85) else {
                    throw SupabaseImageStorageError.imageEncodingFailed
                }

                let newURL = try await imageStorageOrThrow().uploadAvatar(data, for: userID)
                savedProfile.avatarURL = newURL
                if !originalAvatarURL.isEmpty {
                    try await imageStorageOrThrow().deleteImage(at: originalAvatarURL)
                }
            } else if isUsingIconAvatar {
                savedProfile.avatarURL = ""
                if !originalAvatarURL.isEmpty {
                    try await imageStorageOrThrow().deleteImage(at: originalAvatarURL)
                }
            } else {
                savedProfile.avatarURL = originalAvatarURL
            }

            avatarPickerItem = nil
            onSave(savedProfile)
            dismiss()
        } catch {
            avatarError = error.localizedDescription
        }
    }

    @MainActor
    private func importAvatar(from item: PhotosPickerItem) async {
        isLoadingAvatar = true
        defer { isLoadingAvatar = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                return
            }

            pendingAvatarImage = image
            avatarImage = image
            isUsingIconAvatar = false
            avatarError = nil
        } catch {
            return
        }
    }

    private func imageStorageOrThrow() throws -> ImageStorageProviding {
        guard let imageStorage else {
            throw SupabaseImageStorageError.notConfigured
        }
        return imageStorage
    }

    private func symbolLabel(for symbol: String) -> String {
        switch symbol {
        case "leaf.circle.fill": return "Leaf"
        case "binoculars.fill": return "Binoculars"
        case "sun.max.fill": return "Sun"
        case "moon.stars.fill": return "Night"
        case "figure.seated.side": return "Seat"
        case "camera.macro.circle.fill": return "Lens"
        default: return "Icon"
        }
    }
}

private enum EditProfileLongField: String, Identifiable {
    case bio
    case perchStyle
    case favoriteMoment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bio: return "Bio"
        case .perchStyle: return "Perch style"
        case .favoriteMoment: return "Favorite moment"
        }
    }

    var prompt: String {
        switch self {
        case .bio: return "Keep it short and honest."
        case .perchStyle: return "What kinds of spots feel most like you?"
        case .favoriteMoment: return "When does Perch feel best for you?"
        }
    }

    var placeholder: String {
        switch self {
        case .bio: return UserProfile.default.bio
        case .perchStyle: return UserProfile.default.perchStyle
        case .favoriteMoment: return UserProfile.default.favoriteMoment
        }
    }
}

private struct LongTextEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    let title: String
    let prompt: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(prompt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(PerchTheme.controlFill)

                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(placeholder)
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 16)
                    }

                    TextEditor(text: $text)
                        .focused($isFocused)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .textInputAutocapitalization(.sentences)
                }
                .frame(minHeight: 220)

                Text("This change is still a draft until you save the full profile.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(PerchTheme.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Dismiss Keyboard") {
                        isFocused = false
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}
