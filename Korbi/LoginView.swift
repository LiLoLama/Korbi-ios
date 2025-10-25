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
                            .foregroundColor(settings.palette.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .transition(.opacity)
                    }

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

                    Spacer(minLength: 32)
                }
                .padding(.vertical, 48)
            }
        }
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

    private func submit() {
        focusedField = nil
        Task { @MainActor in
            do {
                if isRegistering {
                    try await authManager.register(email: email, password: password, confirmation: confirmation)
                    successMessage = "Registrierung erfolgreich! Bitte prüfe deine E-Mails, um die Registrierung zu bestätigen."
                    clearPasswordFields()
                } else {
                    try await authManager.login(email: email, password: password)
                    successMessage = nil
                    clearForm()
                }
            } catch {
                if let authError = error as? AuthError {
                    errorMessage = authError.errorDescription
                } else {
                    errorMessage = "Etwas ist schiefgelaufen. Bitte versuche es später erneut."
                }
                successMessage = nil
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

    private func clearPasswordFields() {
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
