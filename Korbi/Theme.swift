import SwiftUI

enum KorbiTheme {
    enum Colors {
        static let primary = Color("PrimaryGreen")
        static let background = Color("NeutralBackground")
        static let card = Color("NeutralCard")
        static let accent = Color("AccentSand")
        static let outline = Color("OutlineMist")
        static let textPrimary = Color.primary
        static let textSecondary = Color.primary.opacity(0.6)
    }

    enum Metrics {
        static let cornerRadius: CGFloat = 24
        static let compactCornerRadius: CGFloat = 18
        static let cardPadding: CGFloat = 20
        static let cardSpacing: CGFloat = 18
        static let shadowRadius: CGFloat = 18
    }

    enum Typography {
        static func largeTitle(weight: Font.Weight = .semibold) -> Font {
            .system(size: 34, weight: weight, design: .rounded)
        }

        static func title(weight: Font.Weight = .semibold) -> Font {
            .system(size: 24, weight: weight, design: .rounded)
        }

        static func body(weight: Font.Weight = .regular) -> Font {
            .system(size: 17, weight: weight, design: .default)
        }

        static func caption(weight: Font.Weight = .medium) -> Font {
            .system(size: 13, weight: weight, design: .rounded)
        }
    }
}

struct KorbiBackground: View {
    var body: some View {
        GeometryReader { geometry in
            let gradient = LinearGradient(
                colors: [
                    KorbiTheme.Colors.background.opacity(1.0),
                    KorbiTheme.Colors.background.opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            gradient
                .overlay(
                    Circle()
                        .fill(KorbiTheme.Colors.accent.opacity(0.25))
                        .blur(radius: 120)
                        .frame(width: geometry.size.width * 0.8)
                        .offset(x: geometry.size.width * 0.35, y: -geometry.size.height * 0.15)
                )
                .overlay(
                    Circle()
                        .fill(KorbiTheme.Colors.primary.opacity(0.08))
                        .blur(radius: 160)
                        .frame(width: geometry.size.width * 0.9)
                        .offset(x: -geometry.size.width * 0.4, y: geometry.size.height * 0.55)
                )
                .ignoresSafeArea()
        }
    }
}

struct KorbiCard<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder var content: Content

    init(spacing: CGFloat = KorbiTheme.Metrics.cardSpacing, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .padding(KorbiTheme.Metrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: KorbiTheme.Metrics.cornerRadius, style: .continuous)
                .fill(KorbiTheme.Colors.card)
                .shadow(color: Color.black.opacity(0.08), radius: KorbiTheme.Metrics.shadowRadius, x: 0, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KorbiTheme.Metrics.cornerRadius, style: .continuous)
                .stroke(KorbiTheme.Colors.outline.opacity(0.4), lineWidth: 1)
        )
    }
}

struct PillTag: View {
    let text: String
    let systemImage: String
    var body: some View {
        Label(text, systemImage: systemImage)
            .font(KorbiTheme.Typography.caption())
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(KorbiTheme.Colors.accent.opacity(0.35))
            )
    }
}

struct FloatingMicButton: View {
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: "mic.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .padding(26)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [KorbiTheme.Colors.primary, KorbiTheme.Colors.primary.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: KorbiTheme.Colors.primary.opacity(0.35), radius: 20, x: 0, y: 18)
                )
        }
        .accessibilityLabel("Add with voice")
    }
}
