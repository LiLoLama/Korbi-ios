import SwiftUI

struct Banner: View {
    enum Style {
        case info
        case success
        case warning
        case error

        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.seal.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.octagon.fill"
            }
        }

        var color: Color {
            switch self {
            case .info: return Tokens.tintPrimary
            case .success: return Tokens.success
            case .warning: return Tokens.warning
            case .error: return Tokens.error
            }
        }
    }

    let style: Style
    let message: String
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: style.icon)
                .foregroundStyle(style.color)
                .imageScale(.large)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Tokens.textPrimary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: Spacing.small)
            if let action {
                Button {
                    action()
                } label: {
                    Image(systemName: "xmark")
                        .imageScale(.medium)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Banner schließen"))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Tokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(style.color.opacity(0.35))
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(message))
    }
}

#Preview("Banner") {
    VStack(spacing: 16) {
        Banner(style: .info, message: "Verarbeite Einkaufsliste...")
        Banner(style: .success, message: "Liste aktualisiert!", action: {})
        Banner(style: .warning, message: "Verbindung langsam.")
        Banner(style: .error, message: "Etwas ist schiefgelaufen", action: {})
    }
    .padding()
    .background(Tokens.bgPrimary)
}
