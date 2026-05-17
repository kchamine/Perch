import CoreLocation
import SwiftUI

struct SpotDetailView: View {
    let spot: Spot
    let location: CLLocation?
    let isUserSpot: Bool

    @EnvironmentObject private var store: SpotStore
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var reviewStore: ReviewStore

    @State private var showEditSheet = false
    @State private var showReviewComposer = false
    @State private var pendingDeletionID: UUID?
    @State private var reviewTitle = ""
    @State private var reviewNote = ""
    @State private var settleInEase = 4.0
    @State private var stayComfort = 4.0
    @State private var viewPayoff = 4.0
    @State private var calmFactor = 4.0
    @State private var wouldReturn = true
    @State private var selectedMoments: Set<PerchReviewMoment> = [.soloReset]

    private var currentSpot: Spot {
        isUserSpot ? (store.userSpots.first { $0.id == spot.id } ?? spot) : spot
    }

    private var isFavorite: Bool { favorites.isFavorite(currentSpot) }
    private var reviews: [SpotReview] { reviewStore.reviews(for: currentSpot.id) }
    private var reviewSummary: SpotReviewSummary { reviewStore.summary(for: currentSpot.id) }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                heroSection

                VStack(alignment: .leading, spacing: 24) {
                    editorialSection(title: "About this Perch") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(notesText ?? fallbackDescription)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                            Text(currentSpot.productTextureLine)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PerchTheme.primary)
                                .padding(.top, 2)
                        }
                    }

                    editorialSection(title: "Why trust it") {
                        trustSnapshotCard
                    }

                    editorialSection(title: "Amenities & Vibe") {
                        LazyVGrid(columns: columns, spacing: 14) {
                            amenityRow(icon: "figure.seated.side", title: "Spot type", value: currentSpot.spotType.label)
                            amenityRow(icon: "chair.lounge", title: "Seating", value: currentSpot.seatingType.label)
                            amenityRow(icon: "sun.max", title: "Shade", value: currentSpot.shadeLevel.label)
                            amenityRow(icon: "speaker.wave.2", title: "Noise", value: currentSpot.noiseLevel.label)
                            amenityRow(icon: "person.3", title: "Crowd", value: currentSpot.crowdLevel.label)
                            amenityRow(icon: "sparkles", title: "Best time", value: currentSpot.bestTime.label)
                            amenityRow(icon: "figure.walk", title: "Access", value: currentSpot.accessEffort.label)
                            amenityRow(icon: "accessibility", title: "Accessibility", value: currentSpot.accessibility.label)
                        }
                    }

                    editorialSection(title: "Spot reviews") {
                        VStack(alignment: .leading, spacing: 16) {
                            reviewSummaryCard

                            if reviewSummary.count > 0 {
                                reviewInsightStrip
                            }

                            Button {
                                showReviewComposer = true
                            } label: {
                                Label("Leave a local review", systemImage: "square.and.pencil")
                                    .font(PerchTheme.label(12, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 15)
                                    .background(PerchTheme.surfaceStrong, in: Capsule())
                                    .foregroundStyle(PerchTheme.primary)
                            }
                            .buttonStyle(.plain)

                            if reviews.isEmpty {
                                Text("No one on this device has reviewed this perch yet. Add the first note once you’ve actually sat here.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(alignment: .leading, spacing: 14) {
                                    ForEach(reviews) { review in
                                        reviewCard(review)
                                    }
                                }
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        Button(action: { favorites.toggle(currentSpot) }) {
                            Label(isFavorite ? "Saved" : "Save for later", systemImage: isFavorite ? "bookmark.fill" : "bookmark")
                                .font(PerchTheme.label(12, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(.plain)
                        .background(PerchTheme.surfaceStrong, in: Capsule())
                        .foregroundStyle(PerchTheme.primary)

                        Button {
                            NavigationService.openDirections(for: currentSpot)
                        } label: {
                            HStack(spacing: 8) {
                                Text("Get Directions")
                                Image(systemName: "arrow.right")
                            }
                            .font(PerchTheme.label(12, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [PerchTheme.primary, PerchTheme.primarySoft], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: Capsule()
                            )
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Located \(distanceText) • confirmed \(formattedDate)")
                        .font(PerchTheme.label(10, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(1.1)
                        .foregroundStyle(.secondary.opacity(0.65))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
        }
        .background(PerchTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
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
        .sheet(isPresented: $showEditSheet) {
            AddSpotView(editingSpot: currentSpot)
        }
        .sheet(isPresented: $showReviewComposer) {
            NavigationStack {
                ScrollView {
                    reviewComposerCard
                        .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(PerchTheme.background.ignoresSafeArea())
                .navigationTitle("Leave a review")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            showReviewComposer = false
                        }
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            SeedOrUserPhotoView(spot: currentSpot, style: .photoFit)
                .frame(maxWidth: .infinity)
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 0))
                .overlay {
                    LinearGradient(colors: [.clear, PerchTheme.heroScrim], startPoint: .center, endPoint: .bottom)
                }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(isUserSpot ? "Your Perch" : "Quiet Zone")
                        .font(PerchTheme.label(10, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(PerchTheme.surfaceStrong, in: Capsule())
                        .foregroundStyle(PerchTheme.primary)

                    if currentSpot.isPrivate {
                        Label("Private", systemImage: "lock.fill")
                            .font(PerchTheme.label(10, weight: .bold))
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(PerchTheme.surfaceStrong, in: Capsule())
                            .foregroundStyle(PerchTheme.textMuted)
                    }

                    Spacer()

                    if isUserSpot {
                        Button { showEditSheet = true } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(PerchTheme.textPrimary)
                                .padding(11)
                                .background(PerchTheme.heroScrim, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    if isFavorite {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(PerchTheme.textPrimary)
                            .padding(11)
                            .background(PerchTheme.heroScrim, in: Circle())
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(currentSpot.name)
                        .font(PerchTheme.headline(32))
                        .foregroundStyle(PerchTheme.primary)
                        .lineLimit(2)
                    Text(currentSpot.subtitle)
                        .font(.body.weight(.medium))
                        .foregroundStyle(PerchTheme.textPrimary.opacity(0.92))
                        .lineLimit(2)
                    HStack(spacing: 16) {
                        Label(reviewSummary.count > 0 ? String(format: "%.1f", reviewSummary.averageOverall) : "\(currentSpot.scenicRating).0", systemImage: "star.fill")
                        Label(distanceText, systemImage: "location")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PerchTheme.textPrimary.opacity(0.92))

                    Label(reviewSummary.trustHeadline(fallback: currentSpot), systemImage: reviewSummary.count > 0 ? "checkmark.seal.fill" : "checkmark.seal")
                        .font(PerchTheme.label(10, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(PerchTheme.primary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .perchGlassCard()
            .padding(.horizontal, 20)
            .offset(y: 56)
        }
        .padding(.bottom, 56)
    }

    private func editorialSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(PerchTheme.headline(28))
                .foregroundStyle(PerchTheme.primary)
            content()
        }
    }

    private func amenityRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PerchTheme.primary)
                .frame(width: 38, height: 38)
                .background(PerchTheme.accent.opacity(0.55), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(PerchTheme.label(10, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(PerchTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(PerchTheme.border, lineWidth: 1)
        )
    }

    private var trustSnapshotCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            insightRow(
                icon: reviewSummary.count > 0 ? "checkmark.seal.fill" : "checkmark.seal",
                title: "Trust read",
                value: reviewSummary.trustHeadline(fallback: currentSpot)
            )
            insightRow(
                icon: "calendar.badge.checkmark",
                title: "Confirmation",
                value: "\(currentSpot.confirmationFreshnessLabel) • \(formattedDate)"
            )
            insightRow(
                icon: "exclamationmark.circle",
                title: "Practical caveat",
                value: currentSpot.practicalCaveat
            )

            if let bestFor = reviewSummary.bestForText {
                insightRow(icon: "sparkles", title: "Best use", value: bestFor)
            } else {
                insightRow(icon: "sparkles", title: "Best use", value: currentSpot.productTextureLine)
            }
        }
        .padding(18)
        .background(PerchTheme.accent.opacity(0.32), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var reviewSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reviewSummary.count == 0 ? "No local reviews yet" : String(format: "%.1f / 5 local rating", reviewSummary.averageOverall))
                        .font(PerchTheme.headline(26))
                        .foregroundStyle(PerchTheme.primary)
                    Text(reviewSummary.count == 0 ? "Reviews focus on whether a spot is easy to settle into, comfortable enough to stay, rewarding once seated, and actually calming." : "Based on \(reviewSummary.count) local review\(reviewSummary.count == 1 ? "" : "s") on this device.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if reviewSummary.count > 0 {
                    Text("\(Int((reviewSummary.returnRate * 100).rounded()))% would return")
                        .font(PerchTheme.label(10, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(PerchTheme.textMuted)
                }
            }

            if reviewSummary.count > 0 {
                VStack(spacing: 10) {
                    scoreRow(title: "Settle in fast", value: reviewSummary.averageSettleInEase)
                    scoreRow(title: "Stay-a-while comfort", value: reviewSummary.averageStayComfort)
                    scoreRow(title: "View payoff", value: reviewSummary.averageViewPayoff)
                    scoreRow(title: "Calm factor", value: reviewSummary.averageCalmFactor)
                }
            }
        }
        .padding(18)
        .background(PerchTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var reviewInsightStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let strongest = reviewSummary.strongestDimension {
                insightRow(
                    icon: "sparkles",
                    title: "Strongest signal",
                    value: "\(strongest.label) · \(String(format: "%.1f", strongest.value))/5"
                )
            }

            insightRow(
                icon: reviewSummary.returnRate >= 0.7 ? "arrow.uturn.backward.circle.fill" : "figure.walk",
                title: "Return signal",
                value: reviewSummary.returnRate >= 0.7 ? "People would genuinely come back here." : "More mixed as a repeat perch."
            )

            if !reviewSummary.topMoments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Best for")
                        .font(PerchTheme.label(10, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(.secondary)
                    TagFlowLayout(spacing: 8, rowSpacing: 8) {
                        ForEach(reviewSummary.topMoments, id: \.self) { moment in
                            InlineTag(icon: "checkmark.circle.fill", text: moment.label, tint: PerchTheme.primary)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(PerchTheme.accent.opacity(0.32), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func insightRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PerchTheme.primary)
                .frame(width: 34, height: 34)
                .background(PerchTheme.chipFill, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(PerchTheme.label(10, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PerchTheme.primary)
            }

            Spacer(minLength: 0)
        }
    }

    private func reviewCard(_ review: SpotReview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(review.title)
                        .font(.headline)
                        .foregroundStyle(PerchTheme.primary)
                    Text("by \(review.authorName) • \(review.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                        .background(PerchTheme.surfaceStrong, in: Circle())
                }
                .buttonStyle(.plain)
            }

            if !review.note.isEmpty {
                Text(review.note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }

            HStack(spacing: 8) {
                InlineTag(text: review.wouldReturn ? "Would return" : "One-time stop", tint: review.wouldReturn ? .green : .orange)
                ForEach(review.bestFor, id: \.self) { moment in
                    InlineTag(text: moment.label, tint: PerchTheme.primary)
                }
            }

            LazyVGrid(columns: columns, spacing: 10) {
                miniScoreCard(title: "Settle in", value: review.settleInEase)
                miniScoreCard(title: "Comfort", value: review.stayComfort)
                miniScoreCard(title: "View", value: review.viewPayoff)
                miniScoreCard(title: "Calm", value: review.calmFactor)
            }
        }
        .padding(18)
        .background(PerchTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var reviewComposerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reviewing as \(profileStore.profile.reviewAuthorName)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PerchTheme.textMuted)

            composerField(label: "Title", text: $reviewTitle, prompt: "Quiet midday reset")
            composerField(label: "Notes", text: $reviewNote, prompt: "What was it actually like once you were there?", axis: .vertical)

            reviewSlider(title: "Settle in fast", subtitle: "How easy was it to claim the perch and get oriented?", value: Int(settleInEase), binding: $settleInEase)
            reviewSlider(title: "Stay-a-while comfort", subtitle: "Would you genuinely linger here for a bit?", value: Int(stayComfort), binding: $stayComfort)
            reviewSlider(title: "View payoff", subtitle: "Once seated, how rewarding was the setting?", value: Int(viewPayoff), binding: $viewPayoff)
            reviewSlider(title: "Calm factor", subtitle: "Did the place help you reset or breathe out?", value: Int(calmFactor), binding: $calmFactor)

            Toggle("I’d come back to this spot", isOn: $wouldReturn)
                .tint(PerchTheme.primary)

            VStack(alignment: .leading, spacing: 10) {
                Text("Best for")
                    .font(PerchTheme.label(10, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(.secondary)
                TagFlowLayout(spacing: 8, rowSpacing: 10) {
                    ForEach(PerchReviewMoment.allCases) { moment in
                        Button {
                            if selectedMoments.contains(moment) {
                                selectedMoments.remove(moment)
                            } else {
                                selectedMoments.insert(moment)
                            }
                        } label: {
                            InlineTag(text: moment.label, tint: selectedMoments.contains(moment) ? PerchTheme.primary : .gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                submitReview()
            } label: {
                Label("Save review", systemImage: "checkmark")
                    .font(PerchTheme.label(12, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(colors: [PerchTheme.primary, PerchTheme.primarySoft], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Capsule()
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(PerchTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func composerField(label: String, text: Binding<String>, prompt: String, axis: Axis = .horizontal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(PerchTheme.label(10, weight: .bold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(.secondary)
            TextField(prompt, text: text, axis: axis)
                .padding(14)
                .background(PerchTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func reviewSlider(title: String, subtitle: String, value: Int, binding: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(value)/5")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Slider(value: binding, in: 1...5, step: 1)
                .tint(PerchTheme.primary)
        }
    }

    private func miniScoreCard(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(PerchTheme.label(9, weight: .bold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(.secondary)
            Text("\(value)/5")
                .font(.headline.weight(.bold))
                .foregroundStyle(PerchTheme.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(PerchTheme.accent.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PerchTheme.border, lineWidth: 1)
        )
    }

    private func scoreRow(title: String, value: Double) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PerchTheme.primary)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(PerchTheme.chipFill)
                    Capsule()
                        .fill(PerchTheme.primary)
                        .frame(width: geometry.size.width * CGFloat(max(0, min(value / 5.0, 1))))
                }
            }
            .frame(height: 10)
            Text(String(format: "%.1f", value))
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }

    private func submitReview() {
        reviewStore.addReview(
            spotID: currentSpot.id,
            authorName: profileStore.profile.reviewAuthorName,
            title: reviewTitle,
            note: reviewNote,
            settleInEase: Int(settleInEase),
            stayComfort: Int(stayComfort),
            viewPayoff: Int(viewPayoff),
            calmFactor: Int(calmFactor),
            wouldReturn: wouldReturn,
            bestFor: selectedMoments.isEmpty ? [.soloReset] : Array(selectedMoments)
        )
        reviewTitle = ""
        reviewNote = ""
        settleInEase = 4
        stayComfort = 4
        viewPayoff = 4
        calmFactor = 4
        wouldReturn = true
        selectedMoments = [.soloReset]
        showReviewComposer = false
    }

    private var fallbackDescription: String {
        "A calm place to pause, reset, and take in the setting. Perch is meant to make these small dependable spaces feel discoverable and worth revisiting."
    }

    private var formattedDate: String {
        currentSpot.lastConfirmed.formatted(date: .abbreviated, time: .omitted)
    }

    private var distanceText: String {
        guard let location else { return "distance unavailable" }
        let meters = currentSpot.distance(from: location)
        if meters < 1000 { return "\(Int(meters)) m away" }
        return String(format: "%.1f km away", meters / 1000)
    }

    private var notesText: String? {
        let trimmed = currentSpot.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
