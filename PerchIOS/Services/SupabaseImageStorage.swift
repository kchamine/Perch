import Foundation
import Supabase

protocol ImageStorageProviding {
    func uploadSpotPhoto(_ data: Data) async throws -> String
    func uploadAvatar(_ data: Data, for userID: UUID) async throws -> String
    func deleteImage(at url: String) async throws
    func publicURL(forObjectKey objectKey: String, bucket: SupabaseImageBucket) throws -> String
}

enum SupabaseImageBucket: String, CaseIterable {
    case spotPhotos = "spot-photos"
    case userAvatars = "user-avatars"
}

struct SupabaseImageStorage: ImageStorageProviding {
    private let client: SupabaseClient

    static var shared: SupabaseImageStorage? {
        guard let client = SupabaseClientProvider.shared else { return nil }
        return SupabaseImageStorage(client: client)
    }

    init(client: SupabaseClient) {
        self.client = client
    }

    func uploadSpotPhoto(_ data: Data) async throws -> String {
        let objectKey = "spot-\(UUID().uuidString).jpg"
        return try await upload(data, objectKey: objectKey, bucket: .spotPhotos)
    }

    func uploadAvatar(_ data: Data, for userID: UUID) async throws -> String {
        let objectKey = "\(userID.uuidString)/\(UUID().uuidString).jpg"
        return try await upload(data, objectKey: objectKey, bucket: .userAvatars)
    }

    func deleteImage(at url: String) async throws {
        guard let location = SupabaseImageLocation(publicURLString: url) else {
            return
        }

        try await client.storage
            .from(location.bucket.rawValue)
            .remove(paths: [location.objectKey])
    }

    func publicURL(forObjectKey objectKey: String, bucket: SupabaseImageBucket) throws -> String {
        try client.storage
            .from(bucket.rawValue)
            .getPublicURL(path: objectKey)
            .absoluteString
    }

    private func upload(_ data: Data, objectKey: String, bucket: SupabaseImageBucket) async throws -> String {
        try await client.storage
            .from(bucket.rawValue)
            .upload(
                objectKey,
                data: data,
                options: FileOptions(cacheControl: "31536000", contentType: "image/jpeg", upsert: false)
            )

        return try publicURL(forObjectKey: objectKey, bucket: bucket)
    }
}

struct SupabaseImageLocation: Equatable {
    let bucket: SupabaseImageBucket
    let objectKey: String

    init?(publicURLString: String) {
        guard let url = URL(string: publicURLString) else { return nil }
        let components = url.pathComponents
        guard let publicIndex = components.firstIndex(of: "public") else { return nil }

        let bucketIndex = components.index(after: publicIndex)
        guard components.indices.contains(bucketIndex),
              let bucket = SupabaseImageBucket(rawValue: components[bucketIndex]) else {
            return nil
        }

        let keyStartIndex = components.index(after: bucketIndex)
        guard components.indices.contains(keyStartIndex) else { return nil }

        let objectKey = components[keyStartIndex...].joined(separator: "/")
        guard !objectKey.isEmpty else { return nil }

        self.bucket = bucket
        self.objectKey = objectKey
    }
}

enum SupabaseImageStorageError: LocalizedError {
    case notConfigured
    case unauthenticated
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Perch image storage is not configured in this build."
        case .unauthenticated:
            return "Sign in again before uploading photos."
        case .imageEncodingFailed:
            return "Couldn't prepare that image for upload."
        }
    }
}
