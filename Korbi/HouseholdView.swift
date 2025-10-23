import SwiftUI

struct HouseholdMember: Identifiable {
    let id = UUID()
    let name: String
    let role: String
    let status: String
    let imageName: String
}

struct HouseholdView: View {
    private let members: [HouseholdMember] = [
        .init(name: "Mia", role: "Organisation", status: "Letzter Einkauf abgeschlossen", imageName: "person.circle.fill"),
        .init(name: "Jonas", role: "Küche", status: "Plant Abendessen am Freitag", imageName: "person.crop.circle.badge.checkmark"),
        .init(name: "Ava", role: "Haushalt", status: "Benötigt Waschmittel", imageName: "person.crop.circle")
    ]

    private let routines: [String] = [
        "Mittwochs Obstkorb auffüllen",
        "Samstags gemeinsamer Markttag",
        "Monatliche Vorratsübersicht"
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    memberSection
                    routinesSection
                    inspirationSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(KorbiBackground())
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(KorbiTheme.Colors.background.opacity(0.9), for: .navigationBar)
            .navigationTitle("Haushalt")
        }
    }

    private var memberSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Team Korbi")
                .font(KorbiTheme.Typography.title())
                .foregroundStyle(KorbiTheme.Colors.textPrimary)

            VStack(spacing: 14) {
                ForEach(members) { member in
                    KorbiCard {
                        HStack(spacing: 16) {
                            Image(systemName: member.imageName)
                                .font(.system(size: 32))
                                .foregroundStyle(KorbiTheme.Colors.primary)
                                .frame(width: 56, height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous)
                                        .fill(KorbiTheme.Colors.primary.opacity(0.14))
                                )
                            VStack(alignment: .leading, spacing: 6) {
                                Text(member.name)
                                    .font(KorbiTheme.Typography.body(weight: .semibold))
                                Text(member.role)
                                    .font(KorbiTheme.Typography.caption())
                                    .foregroundStyle(KorbiTheme.Colors.primary.opacity(0.75))
                                Text(member.status)
                                    .font(KorbiTheme.Typography.body())
                                    .foregroundStyle(KorbiTheme.Colors.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(KorbiTheme.Colors.primary.opacity(0.7))
                        }
                    }
                }
            }
        }
    }

    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Routinen")
                .font(KorbiTheme.Typography.title())
                .foregroundStyle(KorbiTheme.Colors.textPrimary)

            KorbiCard {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(routines.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(KorbiTheme.Colors.primary.opacity(0.15))
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(KorbiTheme.Colors.primary, lineWidth: 2)
                                )
                            Text(routines[index])
                                .font(KorbiTheme.Typography.body())
                                .foregroundStyle(KorbiTheme.Colors.textPrimary)
                            Spacer()
                        }
                        if index != routines.indices.last {
                            Divider()
                                .overlay(KorbiTheme.Colors.outline.opacity(0.4))
                        }
                    }

                    Button(action: {}) {
                        Label("Routine hinzufügen", systemImage: "plus")
                            .font(KorbiTheme.Typography.body(weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(KorbiTheme.Colors.primary)
                    .controlSize(.large)
                    .clipShape(RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous))
                }
            }
        }
    }

    private var inspirationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Für mehr Leichtigkeit")
                .font(KorbiTheme.Typography.title())
                .foregroundStyle(KorbiTheme.Colors.textPrimary)

            KorbiCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Balance aus Aufgaben und Pausen")
                        .font(KorbiTheme.Typography.body(weight: .semibold))
                    Text("Korbi erinnert euch daran, Aufgaben gerecht zu verteilen und kleine Auszeiten zu planen. So bleibt der Haushalt entspannt organisiert.")
                        .font(KorbiTheme.Typography.body())
                        .foregroundStyle(KorbiTheme.Colors.textSecondary)
                    HStack {
                        Spacer()
                        Image(systemName: "hands.sparkles.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(KorbiTheme.Colors.primary.opacity(0.7))
                    }
                }
            }
        }
    }
}

#Preview {
    HouseholdView()
}
