import Foundation
import Supabase

enum SupabaseClientProvider {
    // supabase-swift's Auth client owns session persistence and token refresh once auth is wired.
    static let shared: SupabaseClient? = try? makeClient()

    static func makeClient(bundle: Bundle = .main) throws -> SupabaseClient {
        let configuration = try SupabaseClientConfiguration.load(from: bundle)
        return SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.anonKey
        )
    }
}

struct SupabaseClientConfiguration: Equatable {
    let url: URL
    let anonKey: String

    static func load(from bundle: Bundle) throws -> SupabaseClientConfiguration {
        guard let rawURL = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: rawURL),
              !rawURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !rawURL.contains("$(")
        else {
            throw SupabaseClientConfigurationError.missingURL
        }

        guard let rawAnonKey = bundle.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String else {
            throw SupabaseClientConfigurationError.missingAnonKey
        }

        let anonKey = rawAnonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !anonKey.isEmpty, !anonKey.contains("$(") else {
            throw SupabaseClientConfigurationError.missingAnonKey
        }

        return SupabaseClientConfiguration(url: url, anonKey: anonKey)
    }
}

enum SupabaseClientConfigurationError: LocalizedError, Equatable {
    case missingURL
    case missingAnonKey

    var errorDescription: String? {
        switch self {
        case .missingURL:
            return "SUPABASE_URL is missing or invalid in the app configuration."
        case .missingAnonKey:
            return "SUPABASE_ANON_KEY is missing in the app configuration."
        }
    }
}
