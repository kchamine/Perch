import SwiftUI

struct SpotCardView: View {
    let spot: Spot
    let distanceText: String
    let isFavorite: Bool
    let isUserSpot: Bool

    @EnvironmentObject private var reviewStore: ReviewStore

    private var reviewSummary: SpotReviewSummary {
        reviewStore.summary(for: spot.id)
    }

    private var displayRatingText: String {
        let value = reviewSummary.count > 0 ? reviewSummary.averageOverall : Double(spot.scenicRating)
        return String(format: "%.1f", value)
    }

    private var trustHeadline: String {
        reviewSummary.trustHeadline(fallback: spot)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SeedOrUserPhotoView(spot: spot, style: .photoOnly)
                .frame(height: 124)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(spot.name)
                        .font(.headline)
                        .lineLimit(2)
                    Text(spot.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, minHeight: 62, alignment: .topLeading)
                Spacer()
                if isFavorite {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(PerchTheme.primary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Label(trustHeadline, systemImage: reviewSummary.count > 0 ? "checkmark.seal.fill" : "checkmark.seal")
                    .font(PerchTheme.label(10, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.7)
                    .foregroundStyle(PerchTheme.primary)
                    .lineLimit(1)

                Text(reviewSummary.bestForText ?? spot.productTextureLine)
                    .font(.caption)
                    .foregroundStyle(PerchTheme.textMuted)
                    .lineLimit(2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(PerchTheme.accent.opacity(0.34), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            TagFlowLayout(spacing: 8, rowSpacing: 8) {
                InlineTag(icon: "figure.seated.side", text: spot.spotType.label)
                InlineTag(icon: "sparkles", text: displayRatingText)
                InlineTag(icon: "location", text: distanceText)
                InlineTag(icon: "calendar.badge.checkmark", text: spot.confirmationFreshnessLabel, tint: PerchTheme.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .topLeading)

            TagFlowLayout(spacing: 8, rowSpacing: 8) {
                if isUserSpot {
                    InlineTag(icon: "person.crop.circle.badge.checkmark", text: "Added by you", tint: .green)
                }
                if let returnSignal = reviewSummary.returnSignalText {
                    InlineTag(icon: "arrow.uturn.backward.circle", text: returnSignal, tint: .green)
                }
                InlineTag(text: spot.practicalCaveat, tint: PerchTheme.primarySoft)
                InlineTag(text: spot.bestTime.label)
            }
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .topLeading)
        }
        .padding()
        .background(PerchTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PerchTheme.border, lineWidth: 1)
        )
    }
}

struct InlineTag: View {
    var icon: String? = nil
    let text: String
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
            }
            Text(text)
        }
        .font(.caption.weight(.medium))
        .lineLimit(1)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(PerchTheme.chipFill, in: Capsule())
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.24), lineWidth: 1)
        )
        .foregroundStyle(tint)
        .fixedSize()
    }
}

struct TagFlowLayout<Content: View>: View {
    let spacing: CGFloat
    let rowSpacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        FlowLayout(spacing: spacing, rowSpacing: rowSpacing) {
            content
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let proposedWidth = proposal.width.flatMap { $0.isFinite ? $0 : nil }
        let maxWidth = proposedWidth ?? .infinity
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let needsWrap = currentRowWidth > 0 && currentRowWidth + spacing + size.width > maxWidth

            if needsWrap {
                totalHeight += currentRowHeight + rowSpacing
                widestRow = max(widestRow, currentRowWidth)
                currentRowWidth = size.width
                currentRowHeight = size.height
            } else {
                currentRowWidth += currentRowWidth == 0 ? size.width : spacing + size.width
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }

        widestRow = max(widestRow, currentRowWidth)
        totalHeight += currentRowHeight

        // Return the proposed width (when bounded) so the parent allocates proper bounds
        // for placeSubviews — prevents chips from over-running in unbounded scroll contexts.
        let returnWidth = proposedWidth ?? widestRow
        return CGSize(width: returnWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var origin = bounds.origin
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let needsWrap = origin.x > bounds.minX && origin.x + size.width > bounds.maxX

            if needsWrap {
                origin.x = bounds.minX
                origin.y += currentRowHeight + rowSpacing
                currentRowHeight = 0
            }

            subview.place(
                at: origin,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            origin.x += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}
