import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var settings: KorbiSettings
    @EnvironmentObject private var authManager: AuthManager

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmation: String = ""
    @State private var isRegistering = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case email
        case password
        case confirmation
    }

    private var titleText: String {
        isRegistering ? "Neues Konto anlegen" : "Willkommen zurück"
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: settings.backgroundGradient, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundStyle(settings.palette.primary)

                        Text(titleText)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                            .foregroundStyle(settings.palette.textPrimary)

                        Text("Verwalte deinen Haushalt mit Korbi – organisiert, geteilt und nachhaltig.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(settings.palette.textSecondary)
                            .padding(.horizontal)
                    }

                    VStack(spacing: 16) {
                        Picker("Modus", selection: $isRegistering) {
                            Text("Anmelden").tag(false)
                            Text("Registrieren").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        VStack(spacing: 12) {
                            TextField("E-Mail-Adresse", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding()
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(settings.palette.outline, lineWidth: 1)
                                }
                                .focused($focusedField, equals: .email)

                            SecureField("Passwort", text: $password)
                                .textContentType(isRegistering ? .newPassword : .password)
                                .padding()
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(settings.palette.outline, lineWidth: 1)
                                }
                                .focused($focusedField, equals: .password)

                            if isRegistering {
                                SecureField("Passwort bestätigen", text: $confirmation)
                                    .textContentType(.password)
                                    .padding()
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(settings.palette.outline, lineWidth: 1)
                                    }
                                    .focused($focusedField, equals: .confirmation)
                            }
                        }
                        .padding(.horizontal)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .transition(.opacity)
                    }

                    if let successMessage {
                        Text(successMessage)
                            .font(.footnote)
                            .foregroundStyle(settings.palette.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .transition(.opacity)
                    }

                    VStack(spacing: 12) {
                        Button(action: submit) {
                            Text(isRegistering ? "Jetzt registrieren" : "Anmelden")
                                .font(.headline)
                                .foregroundStyle(Color.white)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                                .background(settings.palette.primary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)

                        Button(action: fillDemoCredentials) {
                            HStack(spacing: 8) {
                                Image(systemName: "wand.and.stars.inverse")
                                Text("Demo-Zugang verwenden")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(settings.palette.primary)
                        }

                        Button(action: authManager.loginAsDemoUser) {
                            Text("Direkt als Demo-Benutzer anmelden")
                                .font(.footnote)
                                .underline()
                                .foregroundStyle(settings.palette.textSecondary)
                        }
                    }

                    Spacer(minLength: 32)
                }
                .padding(.vertical, 48)
            }
        }
        .onAppear(perform: presetDemoEmail)
        .onChange(of: isRegistering) { _ in
            withAnimation(.easeInOut) {
                errorMessage = nil
                successMessage = nil
                if isRegistering {
                    focusedField = .email
                } else {
                    confirmation = ""
                }
            }
        }
    }

    private func presetDemoEmail() {
        if email.isEmpty {
            email = authManager.demoCredentials.email
        }
    }

    private func fillDemoCredentials() {
        let credentials = authManager.demoCredentials
        email = credentials.email
        password = credentials.password
        confirmation = credentials.password
    }

    private func submit() {
        focusedField = nil
        successMessage = nil
        Task { @MainActor in
            do {
                if isRegistering {
                    try await authManager.register(email: email, password: password, confirmation: confirmation)
                    successMessage = "Registrierung erfolgreich! Bitte überprüfe deine E-Mails zur Bestätigung."
                } else {
                    try await authManager.login(email: email, password: password)
                }
                clearForm()
            } catch {
                if let authError = error as? AuthError {
                    errorMessage = authError.errorDescription
                } else {
                    errorMessage = "Etwas ist schiefgelaufen. Bitte versuche es später erneut."
                }
            }
        }
    }

    private func clearForm() {
        withAnimation(.easeInOut) {
            password = ""
            confirmation = ""
            errorMessage = nil
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(KorbiSettings())
        .environmentObject(AuthManager())
}
