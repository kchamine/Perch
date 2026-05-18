import XCTest
@testable import PerchIOS

@MainActor
final class ProfileStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "com.perch.profiletests.\(UUID().uuidString)")!
    }

    override func tearDown() async throws {
        defaults = nil
    }

    func testDefaultMapsPreferenceIsAppleMaps() {
        let store = ProfileStore(defaults: defaults)

        XCTAssertEqual(store.profile.mapsAppPreference, .appleMaps)
    }

    func testMapsPreferencePersistsAcrossStoreInstances() {
        let store = ProfileStore(defaults: defaults)
        store.update { profile in
            profile.mapsAppPreference = .googleMaps
        }

        let restored = ProfileStore(defaults: defaults)

        XCTAssertEqual(restored.profile.mapsAppPreference, .googleMaps)
    }
}
