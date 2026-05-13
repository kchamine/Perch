import Foundation
import CoreLocation

struct Spot: Identifiable, Codable, Hashable {
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

enum SeedPhotoKey: String, Codable, CaseIterable {
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
}
