import WidgetKit
import SwiftUI

struct ShoppingListEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot

    var palette: KorbiColorPalette {
        snapshot.useWarmLightMode ? .warmLight : .serene
    }
}

struct WidgetListItem: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let quantity: String
    let description: String
    let category: String
}

struct WidgetSnapshot: Codable, Equatable {
    let householdName: String
    let useWarmLightMode: Bool
    let items: [WidgetListItem]
}

struct Provider: TimelineProvider {
    private let placeholderSnapshot = WidgetSnapshot(
        householdName: "Einkaufsliste",
        useWarmLightMode: false,
        items: [
            WidgetListItem(id: UUID(), name: "Tomaten", quantity: "4 Stück", description: "", category: "Obst & Gemüse"),
            WidgetListItem(id: UUID(), name: "Hafermilch", quantity: "2 l", description: "Barista", category: "Milch & Kühlware"),
            WidgetListItem(id: UUID(), name: "Brot", quantity: "1 Laib", description: "", category: "Backwaren & Frühstück")
        ]
    )

    func placeholder(in context: Context) -> ShoppingListEntry {
        ShoppingListEntry(date: .now, snapshot: placeholderSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (ShoppingListEntry) -> Void) {
        let snapshot = loadSnapshot() ?? placeholderSnapshot
        completion(ShoppingListEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShoppingListEntry>) -> Void) {
        let snapshot = loadSnapshot() ?? placeholderSnapshot
        let entry = ShoppingListEntry(date: .now, snapshot: snapshot)
        let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func loadSnapshot() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: WidgetConstants.appGroupIdentifier)?.data(forKey: WidgetConstants.widgetSnapshotKey) else {
            return nil
        }

        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

struct KorbiWidgetEntryView: View {
    var entry: ShoppingListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            itemsList
            footer
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetBackground(with: entry.palette.backgroundGradient)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "cart.fill")
                .foregroundStyle(entry.palette.primary)
            Text(entry.snapshot.householdName)
                .font(.headline)
                .foregroundStyle(entry.palette.textPrimary)
            Spacer()
            Text("\(entry.snapshot.items.count) Artikel")
                .font(.caption.weight(.semibold))
                .foregroundStyle(entry.palette.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(entry.palette.primary.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private var itemsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(entry.snapshot.items.prefix(5)) { item in
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: iconName(for: item.category))
                        .foregroundStyle(color(for: item))
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(entry.palette.textPrimary)
                        if !item.quantity.isEmpty {
                            Text(item.quantity)
                                .font(.caption)
                                .foregroundStyle(entry.palette.textSecondary)
                        }
                    }
                    Spacer()
                }
            }

            if entry.snapshot.items.isEmpty {
                Text("Keine Artikel in deiner Liste")
                    .font(.caption)
                    .foregroundStyle(entry.palette.textSecondary)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(entry.palette.primary)
                .frame(width: 8, height: 8)
            Text("Aktualisiert")
                .font(.caption)
                .foregroundStyle(entry.palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func color(for item: WidgetListItem) -> Color {
        switch colorRole(for: item.category) {
        case .accent:
            return entry.palette.accent
        case .pantry:
            return Color(red: 0.62, green: 0.53, blue: 0.39)
        default:
            return entry.palette.primary
        }
    }

    private func iconName(for category: String) -> String {
        switch category {
        case "Obst & Gemüse":
            return "leaf.fill"
        case "Backwaren & Frühstück":
            return "bag.fill"
        case "Milch & Kühlware":
            return "drop.fill"
        case "Vorrat & Konserven":
            return "shippingbox.fill"
        case "Süßes & Snacks":
            return "heart.fill"
        case "Getränke":
            return "wineglass.fill"
        case "Tiefkühl":
            return "snowflake"
        case "Drogerie & Körperpflege":
            return "hand.raised.fill"
        case "Haushalt & Reinigung":
            return "house.fill"
        case "Tierbedarf":
            return "pawprint.fill"
        case "Baby & Kind":
            return "person.2.fill"
        default:
            return "ellipsis.circle"
        }
    }

    private func colorRole(for category: String) -> WidgetListColorRole {
        switch category {
        case "Backwaren & Frühstück", "Süßes & Snacks", "Drogerie & Körperpflege", "Baby & Kind":
            return .accent
        case "Vorrat & Konserven", "Tiefkühl", "Haushalt & Reinigung":
            return .pantry
        default:
            return .primary
        }
    }
}

private extension View {
    @ViewBuilder
    func widgetBackground(with gradient: [Color]) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) {
                LinearGradient(
                    colors: gradient,
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        } else {
            background(
                LinearGradient(
                    colors: gradient,
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

struct KorbiWidget: Widget {
    let kind: String = "KorbiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            KorbiWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Einkaufsliste")
        .description("Zeigt deine aktuelle Einkaufsliste im Korbi-Farbschema an.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

fileprivate enum WidgetConstants {
    static let appGroupIdentifier = "group.com.example.korbi"
    static let widgetSnapshotKey = "widgetSnapshot"
}

fileprivate struct KorbiColorPalette {
    let primary: Color
    let background: Color
    let card: Color
    let accent: Color
    let outline: Color
    let textPrimary: Color
    let textSecondary: Color

    var backgroundGradient: [Color] {
        [background, background.opacity(0.96)]
    }

    static let serene = KorbiColorPalette(
        primary: Color("PrimaryGreen"),
        background: Color("NeutralBackground"),
        card: Color("NeutralCard"),
        accent: Color("AccentSand"),
        outline: Color("OutlineMist"),
        textPrimary: Color.primary,
        textSecondary: Color.primary.opacity(0.6)
    )

    static let warmLight = KorbiColorPalette(
        primary: Color(red: 0.78, green: 0.45, blue: 0.29),
        background: Color(red: 0.99, green: 0.96, blue: 0.91),
        card: Color(red: 1.0, green: 0.98, blue: 0.94),
        accent: Color(red: 0.95, green: 0.78, blue: 0.55),
        outline: Color(red: 0.91, green: 0.79, blue: 0.64),
        textPrimary: Color(red: 0.31, green: 0.21, blue: 0.17),
        textSecondary: Color(red: 0.45, green: 0.33, blue: 0.27).opacity(0.75)
    )
}

fileprivate enum WidgetListColorRole {
    case primary
    case accent
    case pantry
}
