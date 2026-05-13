import Foundation
import SwiftUI

enum SpotType: String, Codable, CaseIterable, Identifiable {
    case bench
    case overlook
    case picnicSeat
    case plazaSeat
    case parkEdge
    case waterfront
    case courtyard

    var id: String { rawValue }
    var label: String {
        switch self {
        case .bench: "Bench"
        case .overlook: "Overlook"
        case .picnicSeat: "Picnic table"
        case .plazaSeat: "Plaza"
        case .parkEdge: "Park"
        case .waterfront: "Waterfront"
        case .courtyard: "Courtyard"
        }
    }

    var icon: String {
        switch self {
        case .bench: "figure.seated.side"
        case .overlook: "binoculars"
        case .picnicSeat: "table.furniture"
        case .plazaSeat: "square.grid.2x2"
        case .parkEdge: "leaf"
        case .waterfront: "water.waves"
        case .courtyard: "building.columns"
        }
    }

    var prompt: String {
        switch self {
        case .bench: "A dependable sit-down spot with a clear perch."
        case .overlook: "Chosen mainly for the view or sense of arrival."
        case .picnicSeat: "A table-forward perch where lingering is easy."
        case .plazaSeat: "Open civic seating with room to pause and watch."
        case .parkEdge: "A green public spot for a calmer reset."
        case .waterfront: "A seat or edge that earns its keep through the water."
        case .courtyard: "A tucked-in public nook between buildings or gardens."
        }
    }
}

enum SeatingType: String, Codable, CaseIterable, Identifiable {
    case bench
    case chair
    case picnicTable
    case ledge
    case mixed

    var id: String { rawValue }
    var label: String {
        switch self {
        case .bench: "Bench"
        case .chair: "Chair"
        case .picnicTable: "Picnic table"
        case .ledge: "Ledge"
        case .mixed: "Mixed"
        }
    }
}

enum ShadeLevel: String, Codable, CaseIterable, Identifiable {
    case sunny
    case partial
    case shaded

    var id: String { rawValue }
    var label: String {
        switch self {
        case .sunny: "Mostly sunny"
        case .partial: "Partial shade"
        case .shaded: "Mostly shaded"
        }
    }
}

enum NoiseLevel: String, Codable, CaseIterable, Identifiable {
    case quiet
    case moderate
    case lively

    var id: String { rawValue }
    var label: String {
        switch self {
        case .quiet: "Quiet"
        case .moderate: "Some ambient noise"
        case .lively: "Lively"
        }
    }
}

enum CrowdLevel: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }
    var label: String {
        switch self {
        case .low: "Usually open"
        case .medium: "Some foot traffic"
        case .high: "Often busy"
        }
    }
}

enum ViewType: String, Codable, CaseIterable, Identifiable {
    case water
    case skyline
    case park
    case hill
    case street
    case mixed

    var id: String { rawValue }
    var label: String {
        switch self {
        case .water: "Water"
        case .skyline: "City skyline"
        case .park: "Greenery"
        case .hill: "Hills"
        case .street: "People-watching"
        case .mixed: "Mixed outlook"
        }
    }
}

enum BestTime: String, Codable, CaseIterable, Identifiable {
    case sunrise
    case morning
    case midday
    case afternoon
    case sunset
    case evening

    var id: String { rawValue }
    var label: String {
        switch self {
        case .sunrise: "Sunrise"
        case .morning: "Morning"
        case .midday: "Midday"
        case .afternoon: "Afternoon"
        case .sunset: "Sunset"
        case .evening: "Evening"
        }
    }
}

enum AccessibilityLevel: String, Codable, CaseIterable, Identifiable {
    case wheelchairFriendly
    case stepFree
    case limited
    case unknown

    var id: String { rawValue }
    var label: String {
        switch self {
        case .wheelchairFriendly: "Wheelchair friendly"
        case .stepFree: "Step-free"
        case .limited: "Limited"
        case .unknown: "Unknown"
        }
    }
}

enum AccessEffort: String, Codable, CaseIterable, Identifiable {
    case easy
    case shortWalk
    case moderate

    var id: String { rawValue }
    var label: String {
        switch self {
        case .easy: "Easy"
        case .shortWalk: "Short walk"
        case .moderate: "Moderate"
        }
    }
}

extension ShadeLevel {
    var tint: Color {
        switch self {
        case .sunny: .yellow
        case .partial: .orange
        case .shaded: .green
        }
    }
}

extension NoiseLevel {
    var tint: Color {
        switch self {
        case .quiet: .mint
        case .moderate: .blue
        case .lively: .pink
        }
    }
}

extension CrowdLevel {
    var tint: Color {
        switch self {
        case .low: .green
        case .medium: .orange
        case .high: .red
        }
    }
}

extension ShadeLevel: CustomStringConvertible {
    var description: String { label }
}

extension NoiseLevel: CustomStringConvertible {
    var description: String { label }
}

extension BestTime: CustomStringConvertible {
    var description: String { label }
}
