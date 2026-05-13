import Foundation

struct SpotFilterState: Codable, Hashable {
    var nearbyOnly: Bool = true
    var quietOnly: Bool = false
    var shadedOnly: Bool = false
    var sunsetOnly: Bool = false
    var accessibleOnly: Bool = false
    var easyAccessOnly: Bool = false
    var favoritesOnly: Bool = false

    static let `default` = SpotFilterState()

    var hasActiveFilters: Bool {
        self != .default
    }
}

enum SpotSortOption: String, CaseIterable, Identifiable {
    case distance
    case scenic
    case comfort
    case name
    case recentlyConfirmed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .distance: return "Closest"
        case .scenic: return "Top rated"
        case .comfort: return "Most comfortable"
        case .name: return "A–Z"
        case .recentlyConfirmed: return "Recently confirmed"
        }
    }

    var systemImage: String {
        switch self {
        case .distance: return "location"
        case .scenic: return "star"
        case .comfort: return "chair.lounge"
        case .name: return "textformat.abc"
        case .recentlyConfirmed: return "clock"
        }
    }
}
