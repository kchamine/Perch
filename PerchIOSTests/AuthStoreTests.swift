import Supabase
import XCTest
@testable import PerchIOS

@MainActor
final class AuthStoreTests: XCTestCase {
    private var client: StubAuthClient!
    private var store: AuthStore!

    override func setUp() async throws {
        client = StubAuthClient()
        store = AuthStore(authClient: client)
    }

    override func tearDown() async throws {
        store = nil
        client = nil
    }

    func testInitialSessionPopulatesSession() async {
        let session = makeSession(email: "existing@example.com")
        await Task.yield()

        client.emit(.initialSession(session))
        await waitForAuthState()

        XCTAssertEqual(store.session?.user.email, "existing@example.com")
        XCTAssertEqual(store.currentUser?.email, "existing@example.com")
        XCTAssertFalse(store.isRestoringSession)
    }

    func testSignInSuccessUpdatesSession() async throws {
        let session = makeSession(email: "signin@example.com")
        client.signInResult = .success(session)

        try await store.signIn(email: " signin@example.com ", password: "password123")

        XCTAssertEqual(client.lastSignInEmail, "signin@example.com")
        XCTAssertEqual(store.session?.user.email, "signin@example.com")
    }

    func testSignUpSuccessUpdatesSession() async throws {
        let session = makeSession(email: "signup@example.com")
        client.signUpResult = .success(session)

        try await store.signUp(email: "signup@example.com", password: "password123")

        XCTAssertEqual(store.currentUser?.email, "signup@example.com")
    }

    func testSignOutClearsSession() async throws {
        let session = makeSession(email: "out@example.com")
        client.signInResult = .success(session)
        try await store.signIn(email: "out@example.com", password: "password123")

        try await store.signOut()

        XCTAssertNil(store.session)
        XCTAssertNil(store.currentUser)
        XCTAssertTrue(client.didSignOut)
    }

    func testInvalidCredentialsErrorMapsToAuthErrorInvalidCredentials() async {
        client.signInResult = .failure(PerchAuthError.invalidCredentials)

        do {
            try await store.signIn(email: "bad@example.com", password: "wrong")
            XCTFail("Expected invalid credentials")
        } catch {
            XCTAssertEqual(PerchAuthError.map(error), .invalidCredentials)
        }
    }

    func testEmailInUseErrorMapsToAuthErrorEmailInUse() async {
        client.signUpResult = .failure(PerchAuthError.emailInUse)

        do {
            try await store.signUp(email: "used@example.com", password: "password123")
            XCTFail("Expected email in use")
        } catch {
            XCTAssertEqual(PerchAuthError.map(error), .emailInUse)
        }
    }

    func testNetworkErrorMapsToAuthErrorNetwork() async {
        client.signInResult = .failure(URLError(.notConnectedToInternet))

        do {
            try await store.signIn(email: "offline@example.com", password: "password123")
            XCTFail("Expected network error")
        } catch {
            XCTAssertEqual(PerchAuthError.map(error), .network)
        }
    }

    private func waitForAuthState() async {
        for _ in 0..<5 {
            await Task.yield()
        }
    }
}

final class StubAuthClient: AuthClientProtocol {
    var currentSession: Session?
    var signUpResult: Result<Session?, Error> = .success(nil)
    var signInResult: Result<Session, Error> = .success(makeSession(email: "stub@example.com"))
    var signOutResult: Result<Void, Error> = .success(())
    var lastSignInEmail: String?
    var didSignOut = false

    private var continuation: AsyncStream<PerchAuthStateEvent>.Continuation?

    var authStateEvents: AsyncStream<PerchAuthStateEvent> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    func emit(_ event: PerchAuthStateEvent) {
        continuation?.yield(event)
    }

    func signUp(email: String, password: String) async throws -> Session? {
        switch signUpResult {
        case .success(let session):
            currentSession = session
            return session
        case .failure(let error):
            throw error
        }
    }

    func signIn(email: String, password: String) async throws -> Session {
        lastSignInEmail = email
        switch signInResult {
        case .success(let session):
            currentSession = session
            return session
        case .failure(let error):
            throw error
        }
    }

    func signOut() async throws {
        switch signOutResult {
        case .success:
            didSignOut = true
            currentSession = nil
        case .failure(let error):
            throw error
        }
    }
}

private func makeSession(email: String) -> Session {
    let user = User(
        id: UUID(),
        appMetadata: [:],
        userMetadata: [:],
        aud: "authenticated",
        email: email,
        createdAt: .now,
        updatedAt: .now
    )

    return Session(
        accessToken: "access-token",
        tokenType: "bearer",
        expiresIn: 3600,
        expiresAt: Date().addingTimeInterval(3600).timeIntervalSince1970,
        refreshToken: "refresh-token",
        user: user
    )
}
