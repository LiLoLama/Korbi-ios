import SwiftUI

struct HouseholdMember: Identifiable {
    let id = UUID()
    let name: String
    let role: String
    let status: String
    let imageName: String
}

struct HouseholdView: View {
    @EnvironmentObject private var settings: KorbiSettings

    private let members: [HouseholdMember] = [
        .init(name: "Mia", role: "Organisation", status: "Letzter Einkauf abgeschlossen", imageName: "person.circle.fill"),
        .init(name: "Jonas", role: "Küche", status: "Plant Abendessen am Freitag", imageName: "person.crop.circle.badge.checkmark"),
        .init(name: "Ava", role: "Haushalt", status: "Benötigt Waschmittel", imageName: "person.crop.circle")
    ]

    @State private var routines: [String] = [
        "Mittwochs Obstkorb auffüllen",
        "Samstags gemeinsamer Markttag",
        "Monatliche Vorratsübersicht"
    ]

    @State private var isPresentingRoutineCreator = false
    @State private var newRoutineName = ""
    @State private var isPresentingHouseholdSwitcher = false

    private let availableHouseholds = [
        "Mein Haushalt",
        "WG Hafenstraße",
        "Ferienhaus Ostsee"
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    memberSection
                    routinesSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(KorbiBackground())
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(settings.palette.background.opacity(0.9), for: .navigationBar)
            .navigationTitle("Haushalt")
        }
        .sheet(isPresented: $isPresentingRoutineCreator) {
            RoutineCreatorSheet(
                routineName: $newRoutineName,
                onCancel: dismissRoutineCreator,
                onCreate: finalizeRoutine
            )
            .environmentObject(settings)
        }
        .sheet(isPresented: $isPresentingHouseholdSwitcher) {
            HouseholdSwitcherSheet(
                households: availableHouseholds,
                selectedHousehold: settings.householdName,
                onSelect: switchHousehold,
                onDismiss: { isPresentingHouseholdSwitcher = false }
            )
            .environmentObject(settings)
        }
    }

    private var memberSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text(settings.householdName)
                    .font(KorbiTheme.Typography.title())
                    .foregroundStyle(settings.palette.textPrimary)

                Spacer()

                Button {
                    isPresentingHouseholdSwitcher = true
                } label: {
                    Label("Haushalt wechseln", systemImage: "arrow.triangle.2.circlepath")
                        .labelStyle(.titleAndIcon)
                        .font(KorbiTheme.Typography.body(weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(settings.palette.primary)
                .controlSize(.small)
                .clipShape(RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous))
            }

            VStack(spacing: 14) {
                ForEach(members) { member in
                    KorbiCard {
                        HStack(spacing: 16) {
                            Image(systemName: member.imageName)
                                .font(.system(size: 32))
                                .foregroundStyle(settings.palette.primary)
                                .frame(width: 56, height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous)
                                        .fill(settings.palette.primary.opacity(0.14))
                                )
                            VStack(alignment: .leading, spacing: 6) {
                                Text(member.name)
                                    .font(KorbiTheme.Typography.body(weight: .semibold))
                                Text(member.role)
                                    .font(KorbiTheme.Typography.caption())
                                    .foregroundStyle(settings.palette.primary.opacity(0.75))
                                Text(member.status)
                                    .font(KorbiTheme.Typography.body())
                                    .foregroundStyle(settings.palette.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(settings.palette.primary.opacity(0.7))
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
                .foregroundStyle(settings.palette.textPrimary)

            KorbiCard {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(routines.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(settings.palette.primary.opacity(0.15))
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(settings.palette.primary, lineWidth: 2)
                                )
                            Text(routines[index])
                                .font(KorbiTheme.Typography.body())
                                .foregroundStyle(settings.palette.textPrimary)
                            Spacer()
                        }
                        if index != routines.indices.last {
                            Divider()
                                .overlay(settings.palette.outline.opacity(0.4))
                        }
                    }

                    Button(action: { presentRoutineCreator() }) {
                        Label("Routine hinzufügen", systemImage: "plus")
                            .font(KorbiTheme.Typography.body(weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(settings.palette.primary)
                    .controlSize(.large)
                    .clipShape(RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous))
                }
            }
        }
    }
}

private extension HouseholdView {
    func presentRoutineCreator() {
        newRoutineName = ""
        isPresentingRoutineCreator = true
    }

    func dismissRoutineCreator() {
        isPresentingRoutineCreator = false
    }

    func finalizeRoutine() {
        let trimmedName = newRoutineName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        routines.append(trimmedName)
        isPresentingRoutineCreator = false
    }

    func switchHousehold(to name: String) {
        settings.householdName = name
        isPresentingHouseholdSwitcher = false
    }
}

private struct RoutineCreatorSheet: View {
    @EnvironmentObject private var settings: KorbiSettings
    @Binding var routineName: String
    let onCancel: () -> Void
    let onCreate: () -> Void

    private var isCreateDisabled: Bool {
        routineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Name der Routine")) {
                    TextField("Frische Routine", text: $routineName)
                        .textInputAutocapitalization(.sentences)
                }

                Section(header: Text("Beschreibung")) {
                    Text("Lege eine wiederkehrende Aufgabe fest, die deinem Haushalt hilft, organisiert zu bleiben.")
                        .font(KorbiTheme.Typography.caption())
                        .foregroundStyle(settings.palette.textSecondary)
                        .padding(.vertical, 4)
                }
            }
            .scrollContentBackground(.hidden)
            .background(KorbiBackground())
            .navigationTitle("Routine hinzufügen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern", action: onCreate)
                        .disabled(isCreateDisabled)
                }
            }
        }
    }
}

private struct HouseholdSwitcherSheet: View {
    @EnvironmentObject private var settings: KorbiSettings
    let households: [String]
    let selectedHousehold: String
    let onSelect: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Verfügbare Haushalte")) {
                    ForEach(households, id: \.self) { household in
                        Button {
                            onSelect(household)
                        } label: {
                            HStack {
                                Text(household)
                                    .font(KorbiTheme.Typography.body(weight: .medium))
                                Spacer()
                                if household == selectedHousehold {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(settings.palette.primary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(KorbiBackground())
            .navigationTitle("Haushalt wechseln")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen", action: onDismiss)
                }
            }
        }
    }
}

#Preview {
    HouseholdView()
        .environmentObject(KorbiSettings())
}
