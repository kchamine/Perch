import Foundation

struct SpotReview: Identifiable, Codable, Hashable {
    let id: UUID
    let spotID: UUID
    var authorName: String
    var title: String
    var note: String
    var settleInEase: Int
    var stayComfort: Int
    var viewPayoff: Int
    var calmFactor: Int
    var wouldReturn: Bool
    var bestFor: [PerchReviewMoment]
    var createdAt: Date
    var updatedAt: Date

    var overallRating: Double {
        Double(settleInEase + stayComfort + viewPayoff + calmFactor) / 4.0
    }
}

enum PerchReviewMoment: String, Codable, CaseIterable, Identifiable {
    case soloReset
    case reading
    case coffeeBreak
    case sunsetPause
    case peopleWatching
    case quickBreather

    var id: String { rawValue }

    var label: String {
        switch self {
        case .soloReset: "Solo reset"
        case .reading: "Reading"
        case .coffeeBreak: "Coffee break"
        case .sunsetPause: "Sunset pause"
        case .peopleWatching: "People-watching"
        case .quickBreather: "Quick breather"
        }
    }
}

struct SpotReviewSummary {
    let count: Int
    let averageOverall: Double
    let averageSettleInEase: Double
    let averageStayComfort: Double
    let averageViewPayoff: Double
    let averageCalmFactor: Double
    let returnRate: Double
    let topMoments: [PerchReviewMoment]

    var strongestDimension: (label: String, value: Double)? {
        guard count > 0 else { return nil }
        let dimensions = [
            (label: "Settle in fast", value: averageSettleInEase),
            (label: "Stay-a-while comfort", value: averageStayComfort),
            (label: "View payoff", value: averageViewPayoff),
            (label: "Calm factor", value: averageCalmFactor)
        ]
        return dimensions.max { lhs, rhs in lhs.value < rhs.value }
    }

    static let empty = SpotReviewSummary(
        count: 0,
        averageOverall: 0,
        averageSettleInEase: 0,
        averageStayComfort: 0,
        averageViewPayoff: 0,
        averageCalmFactor: 0,
        returnRate: 0,
        topMoments: []
    )
}


extension SpotReviewSummary {
    func trustHeadline(fallback spot: Spot) -> String {
        if count > 0 {
            if let strongestDimension {
                return "Best signal: \(strongestDimension.label.lowercased())"
            }
            return "Reviewed locally"
        }

        if spot.publicAccessConfirmed && spot.comfortRating >= 4 && spot.scenicRating >= 4 {
            return "Confirmed strong perch"
        }
        if spot.accessEffort == .easy && spot.hasSeating {
            return "Easy sit-down stop"
        }
        if spot.noiseLevel == .quiet {
            return "Quiet reset candidate"
        }
        return "Worth a closer look"
    }

    var returnSignalText: String? {
        guard count > 0 else { return nil }
        let percent = Int((returnRate * 100).rounded())
        return "\(percent)% would return"
    }

    var bestForText: String? {
        guard let first = topMoments.first else { return nil }
        return "Best for \(first.label.lowercased())"
    }
}

extension Spot {
    var confirmationFreshnessLabel: String {
        let days = Calendar.current.dateComponents([.day], from: lastConfirmed, to: .now).day ?? 0
        if days <= 21 { return "Recently confirmed" }
        if days <= 60 { return "Confirmed this season" }
        return "Needs a fresh check"
    }

    var practicalCaveat: String {
        if !publicAccessConfirmed { return "Access still needs confirmation" }
        if accessibility == .limited { return "Limited accessibility" }
        if accessEffort == .moderate { return "Requires a little effort" }
        if crowdLevel == .high { return "Can get busy" }
        if noiseLevel == .lively { return "Lively, not quiet" }
        if shadeLevel == .sunny { return "Limited shade" }
        return "Easy public pause"
    }

    var productTextureLine: String {
        switch viewType {
        case .water: return "Open water, clean sightlines, and a reliable place to exhale."
        case .skyline: return "A view-forward perch for a shorter, more intentional pause."
        case .park: return "Green enough to soften the day without making you plan a whole outing."
        case .hill: return "A bit more effort, usually paid back with quiet and elevation."
        case .street: return "Practical, central, and better for people-watching than silence."
        case .mixed: return "A flexible perch when the mood is more important than the category."
        }
    }
}
