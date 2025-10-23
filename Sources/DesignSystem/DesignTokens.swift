import SwiftUI

public enum Tokens {
    public static let bgPrimary = Color("bgPrimary", bundle: .main)
    public static let bgSecondary = Color("bgSecondary", bundle: .main)
    public static let surface = Color("surface", bundle: .main)
    public static let surfaceAlt = Color("surfaceAlt", bundle: .main)
    public static let textPrimary = Color("textPrimary", bundle: .main)
    public static let textSecondary = Color("textSecondary", bundle: .main)
    public static let tintPrimary = Color("tintPrimary", bundle: .main)
    public static let tintOnPrimary = Color("tintOnPrimary", bundle: .main)
    public static let borderSubtle = Color("borderSubtle", bundle: .main)
    public static let success = Color("success", bundle: .main)
    public static let warning = Color("warning", bundle: .main)
    public static let error = Color("error", bundle: .main)
}

public enum Typography {
    public static let display = Font.system(size: 34, weight: .semibold, design: .rounded)
    public static let title = Font.system(size: 28, weight: .semibold, design: .rounded)
    public static let headline = Font.system(size: 20, weight: .semibold, design: .rounded)
    public static let body = Font.system(size: 17, weight: .regular, design: .default)
    public static let caption = Font.system(size: 13, weight: .regular, design: .default)
}

public enum Spacing {
    public static let xsmall: CGFloat = 4
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 12
    public static let mediumLarge: CGFloat = 16
    public static let large: CGFloat = 20
    public static let xlarge: CGFloat = 24
}

public struct PrimaryButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity)
            .background(Tokens.tintPrimary.opacity(configuration.isPressed ? 0.85 : 1.0))
            .foregroundStyle(Tokens.tintOnPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Tokens.borderSubtle.opacity(0.15))
            )
            .shadow(color: Color.black.opacity(colorSchemeShadow(configuration: configuration)), radius: 8, x: 0, y: 4)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
            .accessibilityAddTraits(.isButton)
    }

    private func colorSchemeShadow(configuration: Configuration) -> Double {
        configuration.isPressed ? 0.05 : 0.12
    }
}

public struct Card<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Tokens.borderSubtle)
            )
            .accessibilityElement(children: .contain)
    }
}

public enum KorbiHaptics {
    public static func lightImpact() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

public struct KorbiShadow: ViewModifier {
    public func body(content: Content) -> some View {
        content.shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}

public extension View {
    func korbiShadow() -> some View {
        modifier(KorbiShadow())
    }
}
