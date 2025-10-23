import SwiftUI

enum KorbiTheme {
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
    @EnvironmentObject private var settings: KorbiSettings

    var body: some View {
        GeometryReader { geometry in
            let gradient = LinearGradient(
                colors: settings.backgroundGradient,
                startPoint: .top,
                endPoint: .bottom
            )

            gradient
                .overlay(
                    Circle()
                        .fill(settings.palette.accent.opacity(settings.useWarmLightMode ? 0.35 : 0.25))
                        .blur(radius: settings.useWarmLightMode ? 160 : 120)
                        .frame(width: geometry.size.width * 0.8)
                        .offset(x: geometry.size.width * 0.35, y: -geometry.size.height * 0.15)
                )
                .overlay(
                    Circle()
                        .fill(settings.palette.primary.opacity(settings.useWarmLightMode ? 0.12 : 0.08))
                        .blur(radius: settings.useWarmLightMode ? 180 : 160)
                        .frame(width: geometry.size.width * 0.9)
                        .offset(x: -geometry.size.width * 0.4, y: geometry.size.height * 0.55)
                )
                .ignoresSafeArea()
        }
    }
}

struct KorbiCard<Content: View>: View {
    @EnvironmentObject private var settings: KorbiSettings
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
                .fill(settings.palette.card)
                .shadow(color: Color.black.opacity(settings.useWarmLightMode ? 0.05 : 0.08), radius: KorbiTheme.Metrics.shadowRadius, x: 0, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KorbiTheme.Metrics.cornerRadius, style: .continuous)
                .stroke(settings.palette.outline.opacity(settings.useWarmLightMode ? 0.5 : 0.4), lineWidth: 1)
        )
    }
}

struct PillTag: View {
    @EnvironmentObject private var settings: KorbiSettings
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(KorbiTheme.Typography.caption())
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(settings.palette.accent.opacity(0.35))
            )
            .foregroundStyle(settings.palette.primary)
    }
}

struct FloatingMicButton: View {
    @EnvironmentObject private var settings: KorbiSettings
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
                                colors: [settings.palette.primary, settings.palette.primary.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: settings.palette.primary.opacity(0.35), radius: 20, x: 0, y: 18)
                )
        }
        .accessibilityLabel("Add with voice")
    }
}
