import SwiftUI

struct EmptyState: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Spacing.large) {
            Image(systemName: systemImage)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundStyle(Tokens.textSecondary)
            VStack(spacing: Spacing.small) {
                Text(title)
                    .font(Typography.headline)
                    .foregroundStyle(Tokens.textPrimary)
                Text(message)
                    .font(Typography.body)
                    .foregroundStyle(Tokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Spacing.xlarge)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Tokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Tokens.borderSubtle)
                )
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview("EmptyState") {
    EmptyState(
        systemImage: "cart",
        title: "Nichts zu tun",
        message: "Füge neue Artikel hinzu, um loszulegen."
    )
    .padding()
    .background(Tokens.bgPrimary)
}
