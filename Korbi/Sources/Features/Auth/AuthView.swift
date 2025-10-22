import SwiftUI
import AuthenticationServices

struct AuthContainerView: View {
  @StateObject var viewModel: AuthViewModel

  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        Spacer()
        VStack(spacing: 12) {
          Image(systemName: "cart.badge.plus")
            .font(.system(size: 56))
            .foregroundStyle(Tokens.tintPrimary)
          Text("Korbi")
            .font(FontTokens.display)
            .foregroundStyle(Tokens.textPrimary)
          Text("Gemeinsam einkaufen – einfach, zuverlässig")
            .font(FontTokens.body)
            .foregroundStyle(Tokens.textSecondary)
            .multilineTextAlignment(.center)
        }

        VStack(spacing: 16) {
          TextField("E-Mail", text: $viewModel.email)
            .keyboardType(.emailAddress)
            .textContentType(.username)
            .padding()
            .background(Tokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Tokens.borderSubtle))

          SecureField("Passwort", text: $viewModel.password)
            .textContentType(.password)
            .padding()
            .background(Tokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Tokens.borderSubtle))

          Button(action: viewModel.submit) {
            HStack {
              if viewModel.isLoading {
                ProgressView()
              }
              Text(viewModel.flow == .signIn ? "Anmelden" : "Registrieren")
            }
          }
          .buttonStyle(PrimaryButtonStyle())
          .disabled(viewModel.isLoading)

          SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.email, .fullName]
          } onCompletion: { result in
            switch result {
            case .success(let auth):
              if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                viewModel.handleAppleCredential(credential)
              }
            case .failure(let error):
              viewModel.errorMessage = error.localizedDescription
            }
          }
          .signInWithAppleButtonStyle(.black)
          .frame(height: 50)
        }

        if let error = viewModel.errorMessage {
          Banner(style: .error(error))
            .transition(.opacity)
        }

        Button(action: viewModel.toggleFlow) {
          Text(viewModel.flow == .signIn ? "Noch kein Konto? Registrieren" : "Schon registriert? Anmelden")
            .font(FontTokens.caption)
            .foregroundStyle(Tokens.textSecondary)
        }
        Spacer()
      }
      .padding(.horizontal, 24)
      .background(Tokens.bgPrimary.ignoresSafeArea())
    }
  }
}
