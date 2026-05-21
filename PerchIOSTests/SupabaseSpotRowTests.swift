import XCTest
@testable import PerchIOS

final class SupabaseSpotRowTests: XCTestCase {
    private let ownerUserID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    func testMapsSpotToSnakeCaseRowJSON() throws {
        let spot = makeSupabaseSpot()
        let row = SupabaseSpotRow(from: spot, ownerUserID: ownerUserID)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(row)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(object?["owner_user_id"] as? String, ownerUserID.uuidString.lowercased())
        XCTAssertEqual(object?["spot_type"] as? String, "bench")
        XCTAssertEqual(object?["seating_type"] as? String, "bench")
        XCTAssertEqual(object?["has_seating"] as? Bool, true)
        XCTAssertEqual(object?["shade_level"] as? String, "partial")
        XCTAssertEqual(object?["noise_level"] as? String, "quiet")
        XCTAssertEqual(object?["crowd_level"] as? String, "low")
        XCTAssertEqual(object?["view_type"] as? String, "park")
        XCTAssertEqual(object?["best_time"] as? String, "afternoon")
        XCTAssertEqual(object?["access_effort"] as? String, "easy")
        XCTAssertEqual(object?["comfort_rating"] as? Int, 4)
        XCTAssertEqual(object?["scenic_rating"] as? Int, 5)
        XCTAssertEqual(object?["public_access_confirmed"] as? Bool, true)
        XCTAssertEqual(object?["is_private"] as? Bool, false)
        XCTAssertEqual(object?["photo_url"] as? String, "https://example.com/spot.jpg")
        XCTAssertEqual(object?["last_confirmed"] as? String, "2026-05-21T19:00:00Z")
    }

    func testRowToSpotPreservesFields() {
        let spot = makeSupabaseSpot()
        let row = SupabaseSpotRow(from: spot, ownerUserID: ownerUserID)

        XCTAssertEqual(row.toSpot(), spot)
    }

    func testRoundTripsAllEnumColumns() {
        for value in SpotType.allCases {
            XCTAssertEqual(SupabaseSpotRow(from: makeSupabaseSpot(spotType: value), ownerUserID: ownerUserID).toSpot().spotType, value)
        }
        for value in SeatingType.allCases {
            XCTAssertEqual(SupabaseSpotRow(from: makeSupabaseSpot(seatingType: value), ownerUserID: ownerUserID).toSpot().seatingType, value)
        }
        for value in ShadeLevel.allCases {
            XCTAssertEqual(SupabaseSpotRow(from: makeSupabaseSpot(shadeLevel: value), ownerUserID: ownerUserID).toSpot().shadeLevel, value)
        }
        for value in NoiseLevel.allCases {
            XCTAssertEqual(SupabaseSpotRow(from: makeSupabaseSpot(noiseLevel: value), ownerUserID: ownerUserID).toSpot().noiseLevel, value)
        }
        for value in CrowdLevel.allCases {
            XCTAssertEqual(SupabaseSpotRow(from: makeSupabaseSpot(crowdLevel: value), ownerUserID: ownerUserID).toSpot().crowdLevel, value)
        }
        for value in ViewType.allCases {
            XCTAssertEqual(SupabaseSpotRow(from: makeSupabaseSpot(viewType: value), ownerUserID: ownerUserID).toSpot().viewType, value)
        }
        for value in BestTime.allCases {
            XCTAssertEqual(SupabaseSpotRow(from: makeSupabaseSpot(bestTime: value), ownerUserID: ownerUserID).toSpot().bestTime, value)
        }
        for value in AccessibilityLevel.allCases {
            XCTAssertEqual(SupabaseSpotRow(from: makeSupabaseSpot(accessibility: value), ownerUserID: ownerUserID).toSpot().accessibility, value)
        }
        for value in AccessEffort.allCases {
            XCTAssertEqual(SupabaseSpotRow(from: makeSupabaseSpot(accessEffort: value), ownerUserID: ownerUserID).toSpot().accessEffort, value)
        }
    }
}

func makeSupabaseSpot(
    id: UUID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
    spotType: SpotType = .bench,
    seatingType: SeatingType = .bench,
    shadeLevel: ShadeLevel = .partial,
    noiseLevel: NoiseLevel = .quiet,
    crowdLevel: CrowdLevel = .low,
    viewType: ViewType = .park,
    bestTime: BestTime = .afternoon,
    accessibility: AccessibilityLevel = .stepFree,
    accessEffort: AccessEffort = .easy
) -> Spot {
    Spot(
        id: id,
        name: "Supabase Spot",
        subtitle: "Synced spot",
        latitude: 37.7749,
        longitude: -122.4194,
        photoName: nil,
        photoURL: "https://example.com/spot.jpg",
        spotType: spotType,
        seatingType: seatingType,
        hasSeating: true,
        shadeLevel: shadeLevel,
        noiseLevel: noiseLevel,
        crowdLevel: crowdLevel,
        viewType: viewType,
        bestTime: bestTime,
        accessibility: accessibility,
        accessEffort: accessEffort,
        comfortRating: 4,
        scenicRating: 5,
        publicAccessConfirmed: true,
        isPrivate: false,
        notes: "Notes",
        lastConfirmed: ISO8601DateFormatter().date(from: "2026-05-21T19:00:00Z")!
    )
}
