import SwiftUI

struct HouseholdView: View {
    @EnvironmentObject private var settings: KorbiSettings

    @State private var routines: [String] = []

    @State private var isPresentingRoutineCreator = false
    @State private var newRoutineName = ""
    @State private var isPresentingHouseholdSwitcher = false

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
                households: settings.households,
                selectedHousehold: settings.currentHousehold,
                onSelect: switchHousehold,
                onDismiss: { isPresentingHouseholdSwitcher = false }
            )
            .environmentObject(settings)
        }
    }

    private var memberSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text(settings.currentHousehold?.name ?? "Haushalt")
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
                .disabled(settings.households.count < 2)
            }

            let members = settings.currentHouseholdMembers
            if members.isEmpty {
                KorbiCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Noch keine Mitglieder")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                            .foregroundStyle(settings.palette.textPrimary)
                        Text("Lade Personen ein, um gemeinsam Listen zu verwalten.")
                            .font(KorbiTheme.Typography.body())
                            .foregroundStyle(settings.palette.textSecondary)
                    }
                }
            } else {
                VStack(spacing: 14) {
                    ForEach(members) { member in
                        KorbiCard {
                            HStack(spacing: 16) {
                                Image(systemName: "person.crop.circle")
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
                                    Text(member.role ?? "Mitglied")
                                        .font(KorbiTheme.Typography.caption())
                                        .foregroundStyle(settings.palette.primary.opacity(0.75))
                                    if let status = member.status, !status.isEmpty {
                                        Text(status)
                                            .font(KorbiTheme.Typography.body())
                                            .foregroundStyle(settings.palette.textSecondary)
                                    }
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
    }

    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Routinen")
                .font(KorbiTheme.Typography.title())
                .foregroundStyle(settings.palette.textPrimary)

            KorbiCard {
                VStack(alignment: .leading, spacing: 12) {
                    if routines.isEmpty {
                        Text("Lege deine erste Routine fest, um Aufgaben zu organisieren.")
                            .font(KorbiTheme.Typography.body())
                            .foregroundStyle(settings.palette.textSecondary)
                    } else {
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

    func switchHousehold(to household: Household) {
        settings.selectHousehold(household)
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
    let households: [Household]
    let selectedHousehold: Household?
    let onSelect: (Household) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Verfügbare Haushalte")) {
                    ForEach(households) { household in
                        Button {
                            onSelect(household)
                        } label: {
                            HStack {
                                Text(household.name)
                                    .font(KorbiTheme.Typography.body(weight: .medium))
                                Spacer()
                                if household.id == selectedHousehold?.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(settings.palette.primary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                if households.isEmpty {
                    Text("Keine Haushalte verfügbar.")
                        .font(KorbiTheme.Typography.body())
                        .foregroundStyle(settings.palette.textSecondary)
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
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
