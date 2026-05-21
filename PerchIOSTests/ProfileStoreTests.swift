import XCTest
@testable import PerchIOS

@MainActor
final class ProfileStoreTests: XCTestCase {
    private var repository: StubProfileRepository!
    private var store: ProfileStore!

    override func setUp() async throws {
        repository = StubProfileRepository()
        store = ProfileStore(repository: repository)
    }

    override func tearDown() async throws {
        store = nil
        repository = nil
    }

    func testDefaultMapsPreferenceIsAppleMaps() {
        XCTAssertEqual(store.profile.mapsAppPreference, .appleMaps)
    }

    func testLoadUsesRepositoryProfile() async {
        var profile = UserProfile.default
        profile.mapsAppPreference = .googleMaps
        profile.displayName = "Kia"
        repository.profile = profile

        await store.load()

        XCTAssertEqual(store.profile.displayName, "Kia")
        XCTAssertEqual(store.profile.mapsAppPreference, .googleMaps)
        XCTAssertNil(store.loadError)
    }

    func testUpdateSavesNormalizedProfile() async {
        store.update { profile in
            profile.displayName = "New Name"
            profile.username = "  @New Name!!  "
            profile.mapsAppPreference = .googleMaps
        }
        await settleAsyncStoreWork()

        XCTAssertEqual(store.profile.displayName, "New Name")
        XCTAssertEqual(store.profile.username, "newname")
        XCTAssertEqual(repository.savedProfiles.last?.displayName, "New Name")
        XCTAssertEqual(repository.savedProfiles.last?.username, "newname")
        XCTAssertEqual(repository.savedProfiles.last?.mapsAppPreference, .googleMaps)
    }

    func testSaveFailureSurfacesLoadErrorWithoutDiscardingProfile() async {
        repository.saveError = TestRepositoryError.failed

        store.update { profile in
            profile.displayName = "Still visible"
        }
        await settleAsyncStoreWork()

        XCTAssertEqual(store.profile.displayName, "Still visible")
        XCTAssertEqual(store.loadError, TestRepositoryError.failed.localizedDescription)
    }

    func testLocalProfileRepositoryPersistsAcrossInstances() async throws {
        let defaults = UserDefaults(suiteName: "com.perch.profiletests.(UUID().uuidString)")!
        let repository = LocalProfileRepository(defaults: defaults)
        var profile = UserProfile.default
        profile.mapsAppPreference = .googleMaps

        try await repository.saveProfile(profile)

        let restored = try await LocalProfileRepository(defaults: defaults).loadProfile()
        XCTAssertEqual(restored.mapsAppPreference, .googleMaps)
    }
}

final class StubProfileRepository: ProfileRepository {
    var profile = UserProfile.default
    var loadError: Error?
    var saveError: Error?
    var savedProfiles: [UserProfile] = []

    func loadProfile() async throws -> UserProfile {
        if let loadError { throw loadError }
        return profile
    }

    func saveProfile(_ profile: UserProfile) async throws {
        if let saveError { throw saveError }
        savedProfiles.append(profile)
        self.profile = profile
    }
}
