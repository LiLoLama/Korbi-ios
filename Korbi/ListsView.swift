import SwiftUI

enum ListColorRole {
    case primary
    case accent
    case pantry
}

struct ShoppingListSummary: Identifiable {
    let id = UUID()
    let title: String
    let itemsDue: Int
    let colorRole: ListColorRole
    let icon: String
}

struct ListsView: View {
    @EnvironmentObject private var settings: KorbiSettings
    @State private var lists: [ShoppingListSummary] = [
        .init(title: "Wocheneinkauf", itemsDue: 8, colorRole: .primary, icon: "basket.fill"),
        .init(title: "Haushalt Essentials", itemsDue: 5, colorRole: .accent, icon: "drop.degreeless.fill"),
        .init(title: "Vorratskammer", itemsDue: 12, colorRole: .pantry, icon: "cube.box.fill")
    ]
    @State private var isPresentingCreateList = false
    @State private var newListName = ""
    @State private var selectedIcon = "basket.fill"

    private let availableIcons = [
        "basket.fill", "cart.fill", "leaf.fill", "carrot.fill", "wineglass.fill", "cup.and.saucer.fill",
        "takeoutbag.and.cup.and.straw.fill", "fork.knife", "shippingbox.fill", "shippingbox", "heart", "tray.fill"
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                KorbiBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Listen")
                            .font(KorbiTheme.Typography.title())
                            .foregroundStyle(settings.palette.textPrimary)

                        LazyVStack(spacing: 20) {
                            ForEach(lists) { list in
                                NavigationLink(destination: listDetail(list)) {
                                    ListCard(summary: list)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 140)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    presentCreateList()
                } label: {
                    Label("Eigene Liste erstellen", systemImage: "plus.circle.fill")
                        .font(KorbiTheme.Typography.body(weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
                .background(settings.palette.primary)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: KorbiTheme.Metrics.cornerRadius, style: .continuous))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .shadow(color: settings.palette.primary.opacity(0.2), radius: 12, y: 4)
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(settings.palette.background.opacity(0.9), for: .navigationBar)
            .navigationTitle("Listen")
        }
        .sheet(isPresented: $isPresentingCreateList) {
            CreateListSheet(
                name: $newListName,
                selectedIcon: $selectedIcon,
                availableIcons: availableIcons,
                onCancel: dismissCreateList,
                onCreate: finalizeCreateList
            )
            .environmentObject(settings)
        }
    }

    private func listDetail(_ summary: ShoppingListSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(summary.title)
                .font(KorbiTheme.Typography.largeTitle())
                .foregroundStyle(settings.palette.textPrimary)
            PillTag(text: "\(summary.itemsDue) offen", systemImage: "clock")
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(settings.palette.background)
    }
}

private extension ListsView {
    func presentCreateList() {
        newListName = ""
        selectedIcon = availableIcons.first ?? "list.bullet"
        isPresentingCreateList = true
    }

    func dismissCreateList() {
        isPresentingCreateList = false
    }

    func finalizeCreateList() {
        let trimmedName = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let newList = ShoppingListSummary(
            title: trimmedName,
            itemsDue: 0,
            colorRole: .primary,
            icon: selectedIcon
        )

        lists.append(newList)
        isPresentingCreateList = false
    }
}

private struct CreateListSheet: View {
    @EnvironmentObject private var settings: KorbiSettings
    @Binding var name: String
    @Binding var selectedIcon: String
    let availableIcons: [String]
    let onCancel: () -> Void
    let onCreate: () -> Void

    private var isCreateDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let gridColumns = [GridItem(.adaptive(minimum: 64), spacing: 16)]

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Name der Liste")) {
                    TextField("Einkaufsplan", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section(header: Text("Icon wählen")) {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 24, weight: .semibold))
                                    .frame(maxWidth: .infinity, minHeight: 56)
                                    .foregroundStyle(settings.palette.primary)
                                    .background(
                                        RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous)
                                            .fill(selectedIcon == icon ? settings.palette.accent.opacity(0.35) : settings.palette.card)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous)
                                            .stroke(selectedIcon == icon ? settings.palette.primary : settings.palette.outline.opacity(0.6), lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(KorbiBackground())
            .navigationTitle("Liste erstellen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Erstellen", action: onCreate)
                        .disabled(isCreateDisabled)
                }
            }
        }
    }
}

private struct ListCard: View {
    @EnvironmentObject private var settings: KorbiSettings
    let summary: ShoppingListSummary

    var body: some View {
        KorbiCard {
            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous)
                        .fill(color.opacity(0.18))
                    Image(systemName: summary.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(color)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 10) {
                    Text(summary.title)
                        .font(KorbiTheme.Typography.body(weight: .semibold))
                        .foregroundStyle(settings.palette.textPrimary)

                    PillTag(text: "\(summary.itemsDue) offen", systemImage: "clock")
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    private var color: Color {
        switch summary.colorRole {
        case .primary:
            return settings.palette.primary
        case .accent:
            return settings.palette.accent
        case .pantry:
            return Color(red: 0.62, green: 0.53, blue: 0.39)
        }
    }
}

#Preview {
    ListsView()
        .environmentObject(KorbiSettings())
}
