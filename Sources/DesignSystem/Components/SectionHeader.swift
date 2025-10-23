import SwiftUI

struct SectionHeader: View {
    let title: String
    var buttonTitle: String?
    var buttonAction: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(Typography.headline)
                .foregroundStyle(Tokens.textPrimary)
            Spacer()
            if let buttonTitle, let buttonAction {
                Button(buttonTitle, action: buttonAction)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Tokens.tintPrimary)
            }
        }
        .padding(.horizontal)
        .padding(.top, Spacing.medium)
        .padding(.bottom, Spacing.small)
        .accessibilityElement(children: .combine)
    }
}

#Preview("SectionHeader") {
    SectionHeader(title: "Zu kaufen", buttonTitle: "Alle") {}
        .background(Tokens.bgPrimary)
}
