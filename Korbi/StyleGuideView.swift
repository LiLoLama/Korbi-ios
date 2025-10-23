import SwiftUI

struct StyleGuideView: View {
    private let palette: [(name: String, color: Color, hex: String)] = [
        ("Primary Green", KorbiTheme.Colors.primary, "#2E6F40"),
        ("Neutral Background", KorbiTheme.Colors.background, "Light #F3F0EB / Dark #17191A"),
        ("Neutral Card", KorbiTheme.Colors.card, "Light #FFFFFF / Dark #2A2C2F"),
        ("Accent Sand", KorbiTheme.Colors.accent, "Light #D9CFC1 / Dark #63584A")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                intro
                colorSection
                typographySection
                componentSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(KorbiTheme.Colors.background)
        .navigationTitle("Korbi Styleguide")
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Korbi Design DNA")
                .font(KorbiTheme.Typography.largeTitle())
            Text("Eine ruhige, freundliche Einkaufserfahrung für Zuhause. Sanfte Naturtöne, runde Formen und klare Typografie schaffen Vertrauen und Alltagstauglichkeit.")
                .font(KorbiTheme.Typography.body())
                .foregroundStyle(KorbiTheme.Colors.textSecondary)
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Farben")
                .font(KorbiTheme.Typography.title())
            VStack(alignment: .leading, spacing: 18) {
                ForEach(palette, id: \.name) { swatch in
                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(swatch.color)
                            .frame(width: 64, height: 64)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(KorbiTheme.Colors.outline.opacity(0.5), lineWidth: 1)
                            )
                        VStack(alignment: .leading, spacing: 6) {
                            Text(swatch.name)
                                .font(KorbiTheme.Typography.body(weight: .semibold))
                            Text(swatch.hex)
                                .font(KorbiTheme.Typography.caption())
                                .foregroundStyle(KorbiTheme.Colors.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private var typographySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Typografie")
                .font(KorbiTheme.Typography.title())
            VStack(alignment: .leading, spacing: 12) {
                Text("SF Pro Rounded / Display")
                    .font(KorbiTheme.Typography.largeTitle())
                Text("SF Pro Text")
                    .font(KorbiTheme.Typography.body(weight: .medium))
                Text("Klar, freundlich und vertraut. Anpassbar für dynamische Schriftgrößen.")
                    .font(KorbiTheme.Typography.body())
                    .foregroundStyle(KorbiTheme.Colors.textSecondary)
            }
        }
    }

    private var componentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Komponenten")
                .font(KorbiTheme.Typography.title())
            VStack(alignment: .leading, spacing: 18) {
                KorbiCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Buttons")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                        HStack(spacing: 16) {
                            Button("Primär") {}
                                .buttonStyle(.borderedProminent)
                                .tint(KorbiTheme.Colors.primary)
                                .controlSize(.large)
                                .clipShape(RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous))
                            Button("Sekundär") {}
                                .buttonStyle(.bordered)
                                .tint(KorbiTheme.Colors.primary)
                                .controlSize(.large)
                                .clipShape(RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous))
                        }
                    }
                }

                KorbiCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cards")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                        Text("Weiche Schatten, großzügige Abstände und klare Hierarchie für schnelle Scans im Alltag.")
                            .font(KorbiTheme.Typography.body())
                            .foregroundStyle(KorbiTheme.Colors.textSecondary)
                    }
                }

                KorbiCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Voice Entry")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                        HStack {
                            FloatingMicButton()
                            Text("Zentral platzierter Sprachbutton für freihändiges Hinzufügen.")
                                .font(KorbiTheme.Typography.body())
                                .foregroundStyle(KorbiTheme.Colors.textSecondary)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        StyleGuideView()
    }
}
