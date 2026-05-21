import Foundation

struct SupabaseSpotRow: Codable, Equatable {
    let id: UUID
    let ownerUserID: UUID
    let name: String
    let subtitle: String
    let latitude: Double
    let longitude: Double
    let spotType: SpotType
    let seatingType: SeatingType
    let hasSeating: Bool
    let shadeLevel: ShadeLevel
    let noiseLevel: NoiseLevel
    let crowdLevel: CrowdLevel
    let viewType: ViewType
    let bestTime: BestTime
    let accessibility: AccessibilityLevel
    let accessEffort: AccessEffort
    let comfortRating: Int
    let scenicRating: Int
    let publicAccessConfirmed: Bool
    let isPrivate: Bool
    let photoURL: String?
    let notes: String
    let lastConfirmed: Date
    let createdAt: Date?
    let updatedAt: Date?

    init(from spot: Spot, ownerUserID: UUID, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = spot.id
        self.ownerUserID = ownerUserID
        self.name = spot.name
        self.subtitle = spot.subtitle
        self.latitude = spot.latitude
        self.longitude = spot.longitude
        self.spotType = spot.spotType
        self.seatingType = spot.seatingType
        self.hasSeating = spot.hasSeating
        self.shadeLevel = spot.shadeLevel
        self.noiseLevel = spot.noiseLevel
        self.crowdLevel = spot.crowdLevel
        self.viewType = spot.viewType
        self.bestTime = spot.bestTime
        self.accessibility = spot.accessibility
        self.accessEffort = spot.accessEffort
        self.comfortRating = spot.comfortRating
        self.scenicRating = spot.scenicRating
        self.publicAccessConfirmed = spot.publicAccessConfirmed
        self.isPrivate = spot.isPrivate
        self.photoURL = spot.photoURL
        self.notes = spot.notes
        self.lastConfirmed = spot.lastConfirmed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func toSpot() -> Spot {
        Spot(
            id: id,
            name: name,
            subtitle: subtitle,
            latitude: latitude,
            longitude: longitude,
            photoName: nil,
            photoURL: photoURL,
            spotType: spotType,
            seatingType: seatingType,
            hasSeating: hasSeating,
            shadeLevel: shadeLevel,
            noiseLevel: noiseLevel,
            crowdLevel: crowdLevel,
            viewType: viewType,
            bestTime: bestTime,
            accessibility: accessibility,
            accessEffort: accessEffort,
            comfortRating: comfortRating,
            scenicRating: scenicRating,
            publicAccessConfirmed: publicAccessConfirmed,
            isPrivate: isPrivate,
            notes: notes,
            lastConfirmed: lastConfirmed
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case name
        case subtitle
        case latitude
        case longitude
        case spotType = "spot_type"
        case seatingType = "seating_type"
        case hasSeating = "has_seating"
        case shadeLevel = "shade_level"
        case noiseLevel = "noise_level"
        case crowdLevel = "crowd_level"
        case viewType = "view_type"
        case bestTime = "best_time"
        case accessibility
        case accessEffort = "access_effort"
        case comfortRating = "comfort_rating"
        case scenicRating = "scenic_rating"
        case publicAccessConfirmed = "public_access_confirmed"
        case isPrivate = "is_private"
        case photoURL = "photo_url"
        case notes
        case lastConfirmed = "last_confirmed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
