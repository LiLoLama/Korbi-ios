import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .accessibilityLabel(Text(title))
    }
}

#Preview("PrimaryButton Light") {
    PrimaryButton("Bestätigen", action: {})
        .padding()
        .background(Tokens.bgPrimary)
}

#Preview("PrimaryButton Dark") {
    PrimaryButton("Bestätigen", action: {})
        .padding()
        .background(Tokens.bgPrimary)
        .environment(\.colorScheme, .dark)
}
