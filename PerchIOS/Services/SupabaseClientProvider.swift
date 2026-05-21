import Foundation
import Supabase

enum SupabaseClientProvider {
    // supabase-swift's Auth client owns session persistence and token refresh once auth is wired.
    static let shared: SupabaseClient? = try? makeClient()

    static func makeClient(bundle: Bundle = .main) throws -> SupabaseClient {
        let configuration = try SupabaseClientConfiguration.load(from: bundle)
        return SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.publishableKey
        )
    }
}

struct SupabaseClientConfiguration: Equatable {
    let url: URL
    let publishableKey: String

    static func load(from bundle: Bundle) throws -> SupabaseClientConfiguration {
        guard let rawURL = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: rawURL),
              !rawURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !rawURL.contains("$(")
        else {
            throw SupabaseClientConfigurationError.missingURL
        }

        guard let rawPublishableKey = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String else {
            throw SupabaseClientConfigurationError.missingPublishableKey
        }

        let publishableKey = rawPublishableKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !publishableKey.isEmpty, !publishableKey.contains("$(") else {
            throw SupabaseClientConfigurationError.missingPublishableKey
        }

        return SupabaseClientConfiguration(url: url, publishableKey: publishableKey)
    }
}

enum SupabaseClientConfigurationError: LocalizedError, Equatable {
    case missingURL
    case missingPublishableKey

    var errorDescription: String? {
        switch self {
        case .missingURL:
            return "SUPABASE_URL is missing or invalid in the app configuration."
        case .missingPublishableKey:
            return "SUPABASE_PUBLISHABLE_KEY is missing in the app configuration."
        }
    }
}
