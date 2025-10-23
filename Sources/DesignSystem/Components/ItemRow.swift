import SwiftUI

struct ItemRow: View {
    let item: Item
    let togglePurchased: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(Tokens.textPrimary)
                if let quantity = item.quantityText, !quantity.isEmpty {
                    Text(quantity)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Tokens.textSecondary)
                }
            }
            Spacer()
            if item.status == .open {
                Text("Offen")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Tokens.bgSecondary)
                    .clipShape(Capsule())
                    .foregroundStyle(Tokens.textSecondary)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Tokens.success)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .swipeActions(edge: .leading) {
            Button {
                togglePurchased()
            } label: {
                Label("Erledigt", systemImage: "checkmark")
            }
            .tint(Tokens.tintPrimary)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                delete()
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(item.status == .open ? "Nach rechts streichen, um als erledigt zu markieren" : "Nach links streichen, um zu löschen")
    }
}

#Preview("ItemRow") {
    VStack(spacing: 12) {
        ItemRow(
            item: Item(id: UUID(), name: "Hafermilch", quantityText: "2 x 1L", status: .open),
            togglePurchased: {},
            delete: {}
        )
        ItemRow(
            item: Item(id: UUID(), name: "Kaffee", quantityText: nil, status: .purchased),
            togglePurchased: {},
            delete: {}
        )
    }
    .padding()
    .background(Tokens.bgPrimary)
}
