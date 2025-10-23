import SwiftUI

struct StyleGuideView: View {
    @EnvironmentObject private var settings: KorbiSettings

    private var palette: [(name: String, color: Color, description: String)] {
        [
            ("Primär", settings.palette.primary, "Key Action & Highlights"),
            ("Hintergrund", settings.palette.background, "Flächen & Szenen"),
            ("Card", settings.palette.card, "Module & Panels"),
            ("Akzent", settings.palette.accent, "Hinweise & Tags")
        ]
    }

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
        .background(settings.palette.background)
        .navigationTitle("Korbi Styleguide")
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Korbi Design DNA")
                .font(KorbiTheme.Typography.largeTitle())
                .foregroundStyle(settings.palette.textPrimary)
            Text("Eine ruhige, freundliche Einkaufserfahrung für Zuhause. Sanfte Naturtöne, runde Formen und klare Typografie schaffen Vertrauen und Alltagstauglichkeit.")
                .font(KorbiTheme.Typography.body())
                .foregroundStyle(settings.palette.textSecondary)
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Farben")
                .font(KorbiTheme.Typography.title())
                .foregroundStyle(settings.palette.textPrimary)
            VStack(alignment: .leading, spacing: 18) {
                ForEach(palette, id: \.name) { swatch in
                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(swatch.color)
                            .frame(width: 64, height: 64)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(settings.palette.outline.opacity(0.5), lineWidth: 1)
                            )
                        VStack(alignment: .leading, spacing: 6) {
                            Text(swatch.name)
                                .font(KorbiTheme.Typography.body(weight: .semibold))
                                .foregroundStyle(settings.palette.textPrimary)
                            Text(swatch.description)
                                .font(KorbiTheme.Typography.caption())
                                .foregroundStyle(settings.palette.textSecondary)
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
                .foregroundStyle(settings.palette.textPrimary)
            VStack(alignment: .leading, spacing: 12) {
                Text("SF Pro Rounded / Display")
                    .font(KorbiTheme.Typography.largeTitle())
                    .foregroundStyle(settings.palette.textPrimary)
                Text("SF Pro Text")
                    .font(KorbiTheme.Typography.body(weight: .medium))
                    .foregroundStyle(settings.palette.textPrimary)
                Text("Klar, freundlich und vertraut. Anpassbar für dynamische Schriftgrößen.")
                    .font(KorbiTheme.Typography.body())
                    .foregroundStyle(settings.palette.textSecondary)
            }
        }
    }

    private var componentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Komponenten")
                .font(KorbiTheme.Typography.title())
                .foregroundStyle(settings.palette.textPrimary)
            VStack(alignment: .leading, spacing: 18) {
                KorbiCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Buttons")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                            .foregroundStyle(settings.palette.textPrimary)
                        HStack(spacing: 16) {
                            Button("Primär") {}
                                .buttonStyle(.borderedProminent)
                                .tint(settings.palette.primary)
                                .controlSize(.large)
                                .clipShape(RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous))
                            Button("Sekundär") {}
                                .buttonStyle(.bordered)
                                .tint(settings.palette.primary)
                                .controlSize(.large)
                                .clipShape(RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous))
                        }
                    }
                }

                KorbiCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cards")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                            .foregroundStyle(settings.palette.textPrimary)
                        Text("Weiche Schatten, großzügige Abstände und klare Hierarchie für schnelle Scans im Alltag.")
                            .font(KorbiTheme.Typography.body())
                            .foregroundStyle(settings.palette.textSecondary)
                    }
                }

                KorbiCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Voice Entry")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                            .foregroundStyle(settings.palette.textPrimary)
                        HStack {
                            FloatingMicButton()
                            Text("Zentral platzierter Sprachbutton für freihändiges Hinzufügen.")
                                .font(KorbiTheme.Typography.body())
                                .foregroundStyle(settings.palette.textSecondary)
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
            .environmentObject(KorbiSettings())
    }
}
