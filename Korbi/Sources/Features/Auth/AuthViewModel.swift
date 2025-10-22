import Foundation
import Combine
import AuthenticationServices
import UIKit

@MainActor
final class AuthViewModel: NSObject, ObservableObject, ASAuthorizationControllerPresentationContextProviding {
  enum Flow {
    case signIn
    case register
  }

  @Published var email: String = ""
  @Published var password: String = ""
  @Published var flow: Flow = .signIn
  @Published var isLoading: Bool = false
  @Published var errorMessage: String?

  private let authService: AuthServicing

  init(authService: AuthServicing) {
    self.authService = authService
  }

  func toggleFlow() {
    flow = flow == .signIn ? .register : .signIn
    errorMessage = nil
  }

  func submit() {
    Task {
      do {
        isLoading = true
        switch flow {
        case .signIn:
          try await authService.signIn(email: email, password: password)
        case .register:
          try await authService.signUp(email: email, password: password)
        }
        errorMessage = nil
      } catch {
        errorMessage = error.localizedDescription
      }
      isLoading = false
    }
  }

  func handleAppleCredential(_ credential: ASAuthorizationAppleIDCredential) {
    Task {
      do {
        try await authService.signInWithApple(result: credential)
        errorMessage = nil
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
  }
}
