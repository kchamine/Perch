import XCTest
@testable import PerchIOS

final class SupabaseImageStorageTests: XCTestCase {
    func testParsesSpotPhotoPublicURL() {
        let location = SupabaseImageLocation(
            publicURLString: "https://vuvtavravnenbemrgloy.supabase.co/storage/v1/object/public/spot-photos/spot-123.jpg"
        )

        XCTAssertEqual(location?.bucket, .spotPhotos)
        XCTAssertEqual(location?.objectKey, "spot-123.jpg")
    }

    func testParsesAvatarPublicURLWithNestedObjectKey() {
        let location = SupabaseImageLocation(
            publicURLString: "https://vuvtavravnenbemrgloy.supabase.co/storage/v1/object/public/user-avatars/8B56/avatar.jpg"
        )

        XCTAssertEqual(location?.bucket, .userAvatars)
        XCTAssertEqual(location?.objectKey, "8B56/avatar.jpg")
    }

    func testRejectsUnknownBucketURL() {
        let location = SupabaseImageLocation(
            publicURLString: "https://vuvtavravnenbemrgloy.supabase.co/storage/v1/object/public/other/image.jpg"
        )

        XCTAssertNil(location)
    }
}
