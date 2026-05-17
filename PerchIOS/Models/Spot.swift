import Foundation
import CoreLocation

struct Spot: Identifiable, Hashable {
    let id: UUID
    var name: String
    var subtitle: String
    var latitude: Double
    var longitude: Double
    var photoName: String?
    var userPhotoPath: String?
    var spotType: SpotType
    var seatingType: SeatingType
    var hasSeating: Bool
    var shadeLevel: ShadeLevel
    var noiseLevel: NoiseLevel
    var crowdLevel: CrowdLevel
    var viewType: ViewType
    var bestTime: BestTime
    var accessibility: AccessibilityLevel
    var accessEffort: AccessEffort
    var comfortRating: Int
    var scenicRating: Int
    var publicAccessConfirmed: Bool
    var isPrivate: Bool
    var notes: String
    var lastConfirmed: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var seedPhotoKey: SeedPhotoKey? {
        guard let photoName else { return nil }
        return SeedPhotoKey(rawValue: photoName)
    }
}

extension Spot: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, subtitle, latitude, longitude, photoName, userPhotoPath
        case spotType, seatingType, hasSeating, shadeLevel, noiseLevel, crowdLevel
        case viewType, bestTime, accessibility, accessEffort, comfortRating, scenicRating
        case publicAccessConfirmed, isPrivate, notes, lastConfirmed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        photoName = try container.decodeIfPresent(String.self, forKey: .photoName)
        userPhotoPath = try container.decodeIfPresent(String.self, forKey: .userPhotoPath)
        spotType = try container.decode(SpotType.self, forKey: .spotType)
        seatingType = try container.decode(SeatingType.self, forKey: .seatingType)
        hasSeating = try container.decode(Bool.self, forKey: .hasSeating)
        shadeLevel = try container.decode(ShadeLevel.self, forKey: .shadeLevel)
        noiseLevel = try container.decode(NoiseLevel.self, forKey: .noiseLevel)
        crowdLevel = try container.decode(CrowdLevel.self, forKey: .crowdLevel)
        viewType = try container.decode(ViewType.self, forKey: .viewType)
        bestTime = try container.decode(BestTime.self, forKey: .bestTime)
        accessibility = try container.decode(AccessibilityLevel.self, forKey: .accessibility)
        accessEffort = try container.decode(AccessEffort.self, forKey: .accessEffort)
        comfortRating = try container.decode(Int.self, forKey: .comfortRating)
        scenicRating = try container.decode(Int.self, forKey: .scenicRating)
        publicAccessConfirmed = try container.decode(Bool.self, forKey: .publicAccessConfirmed)
        isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
        notes = try container.decode(String.self, forKey: .notes)
        lastConfirmed = try container.decode(Date.self, forKey: .lastConfirmed)
    }
}

enum SeedPhotoKey: String, Codable, CaseIterable {
    // San Francisco
    case ferryLanding
    case eucalyptusBench
    case cityOutlook
    case roseGarden
    case baySteps
    case pointBench
    case libraryPlaza
    case marinaSeat
    case hillRest
    case quietGreen
    case waterfrontLedge
    case sunsetTerrace
    // New York City
    case centralParkBench
    case highLineLedge
    case brooklynBridgePark
    // Los Angeles
    case griffithOverlook
    case veniceBeachPerch
    case echoLakeSeat
    // Seattle
    case kerryParkBench
    case waterfrontPier
    case discoveryParkEdge
}
