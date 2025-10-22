import Foundation
import Combine
import Supabase
import AuthenticationServices

protocol AuthServicing {
  var authStatePublisher: AnyPublisher<AuthSession?, Never> { get }
  func signUp(email: String, password: String) async throws
  func signIn(email: String, password: String) async throws
  func signInWithApple(result: ASAuthorizationAppleIDCredential) async throws
  func signOut() async throws
  var currentUserID: UUID? { get }
}

final class AuthService: AuthServicing {
  private let client: SupabaseClient
  private let stateSubject = CurrentValueSubject<AuthSession?, Never>(nil)

  var authStatePublisher: AnyPublisher<AuthSession?, Never> {
    stateSubject.eraseToAnyPublisher()
  }

  init(client: SupabaseClient) {
    self.client = client
    Task {
      await refreshSession()
    }
  }

  func signUp(email: String, password: String) async throws {
    let response = try await client.auth.signUp(email: email, password: password)
    if let session = response.session, let user = session.user {
      stateSubject.send(AuthSession(userID: user.id, email: user.email))
    }
  }

  func signIn(email: String, password: String) async throws {
    let response = try await client.auth.signIn(email: email, password: password)
    if let user = response.user {
      stateSubject.send(AuthSession(userID: user.id, email: user.email))
    }
  }

  func signInWithApple(result: ASAuthorizationAppleIDCredential) async throws {
    guard let identityToken = result.identityToken else {
      throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Fehlendes Identity Token"])
    }
    let tokenString = String(decoding: identityToken, as: UTF8.self)
    let nonce = result.state ?? UUID().uuidString
    let response = try await client.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: tokenString, nonce: nonce))
    if let user = response.user {
      stateSubject.send(AuthSession(userID: user.id, email: user.email))
    }
  }

  func signOut() async throws {
    try await client.auth.signOut()
    stateSubject.send(nil)
  }

  var currentUserID: UUID? {
    client.auth.currentUser?.id
  }

  @MainActor
  private func refreshSession() async {
    if let user = client.auth.currentUser {
      stateSubject.send(AuthSession(userID: user.id, email: user.email))
    } else {
      stateSubject.send(nil)
    }
  }
}
