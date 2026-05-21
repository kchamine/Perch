import Foundation
import Supabase

enum PerchAuthStateEvent {
    case initialSession(Session?)
    case signedIn(Session)
    case signedOut
    case tokenRefreshed(Session)
}

protocol AuthClientProtocol {
    var currentSession: Session? { get }
    var authStateEvents: AsyncStream<PerchAuthStateEvent> { get }

    func signUp(email: String, password: String) async throws -> Session?
    func signIn(email: String, password: String) async throws -> Session
    func signOut() async throws
}

struct SupabaseAuthClientAdapter: AuthClientProtocol {
    let client: SupabaseClient

    var currentSession: Session? {
        client.auth.currentSession
    }

    var authStateEvents: AsyncStream<PerchAuthStateEvent> {
        AsyncStream { continuation in
            let task = Task {
                for await change in client.auth.authStateChanges {
                    switch change.event {
                    case .initialSession:
                        continuation.yield(.initialSession(change.session))
                    case .signedIn:
                        if let session = change.session {
                            continuation.yield(.signedIn(session))
                        }
                    case .signedOut, .userDeleted:
                        continuation.yield(.signedOut)
                    case .tokenRefreshed:
                        if let session = change.session {
                            continuation.yield(.tokenRefreshed(session))
                        }
                    default:
                        break
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func signUp(email: String, password: String) async throws -> Session? {
        try await client.auth.signUp(email: email, password: password).session
    }

    func signIn(email: String, password: String) async throws -> Session {
        try await client.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }
}

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var session: Session?
    @Published private(set) var currentUser: User?
    @Published private(set) var isRestoringSession = true
    @Published private(set) var configurationError: PerchAuthError?

    private let authClient: AuthClientProtocol?
    private var authStateTask: Task<Void, Never>?

    var isSignedIn: Bool {
        session != nil
    }

    convenience init() {
        if let client = SupabaseClientProvider.shared {
            self.init(authClient: SupabaseAuthClientAdapter(client: client))
        } else {
            self.init(authClient: nil, configurationError: .notConfigured)
        }
    }

    init(authClient: AuthClientProtocol?, configurationError: PerchAuthError? = nil) {
        self.authClient = authClient
        self.configurationError = configurationError

        guard let authClient else {
            isRestoringSession = false
            return
        }

        apply(session: authClient.currentSession)
        observeAuthState(from: authClient)
    }

    deinit {
        authStateTask?.cancel()
    }

    func signUp(email: String, password: String) async throws {
        guard let authClient else {
            throw PerchAuthError.notConfigured
        }

        do {
            let session = try await authClient.signUp(email: normalizedEmail(email), password: password)
            if let session {
                apply(session: session)
            }
        } catch {
            throw PerchAuthError.map(error)
        }
    }

    func signIn(email: String, password: String) async throws {
        guard let authClient else {
            throw PerchAuthError.notConfigured
        }

        do {
            let session = try await authClient.signIn(email: normalizedEmail(email), password: password)
            apply(session: session)
        } catch {
            throw PerchAuthError.map(error)
        }
    }

    func signOut() async throws {
        guard let authClient else {
            throw PerchAuthError.notConfigured
        }

        do {
            try await authClient.signOut()
            apply(session: nil)
        } catch {
            throw PerchAuthError.map(error)
        }
    }

    private func observeAuthState(from authClient: AuthClientProtocol) {
        authStateTask = Task { [weak self] in
            for await event in authClient.authStateEvents {
                guard let self else { return }
                self.apply(event)
            }
        }
    }

    private func apply(_ event: PerchAuthStateEvent) {
        switch event {
        case .initialSession(let session):
            apply(session: session)
            isRestoringSession = false
        case .signedIn(let session), .tokenRefreshed(let session):
            apply(session: session)
            isRestoringSession = false
        case .signedOut:
            apply(session: nil)
            isRestoringSession = false
        }
    }

    private func apply(session: Session?) {
        self.session = session
        currentUser = session?.user
    }

    private func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum PerchAuthError: LocalizedError, Equatable {
    case notConfigured
    case invalidCredentials
    case emailInUse
    case weakPassword
    case network
    case unknown

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Perch account sync is not configured in this build."
        case .invalidCredentials:
            return "Email or password is incorrect."
        case .emailInUse:
            return "That email already has an account."
        case .weakPassword:
            return "Choose a stronger password."
        case .network:
            return "Couldn't reach the network. Try again."
        case .unknown:
            return "Something went wrong. Try again."
        }
    }

    static func map(_ error: Error) -> PerchAuthError {
        if let perchError = error as? PerchAuthError {
            return perchError
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost:
                return .network
            default:
                break
            }
        }

        if let authError = error as? Supabase.AuthError {
            return mapSupabaseAuthError(authError)
        }

        return .unknown
    }

    private static func mapSupabaseAuthError(_ error: Supabase.AuthError) -> PerchAuthError {
        switch error {
        case .weakPassword:
            return .weakPassword
        default:
            let message = error.message.lowercased()
            if message.contains("already") || message.contains("registered") || message.contains("exists") {
                return .emailInUse
            }
            if message.contains("invalid") || message.contains("credential") || message.contains("password") || message.contains("login") {
                return .invalidCredentials
            }
            return .unknown
        }
    }
}
