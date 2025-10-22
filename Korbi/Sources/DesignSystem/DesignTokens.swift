import SwiftUI

enum Tokens {
  static let bgPrimary = Color("bgPrimary", bundle: .main)
  static let bgSecondary = Color("bgSecondary", bundle: .main)
  static let surface = Color("surface", bundle: .main)
  static let surfaceAlt = Color("surfaceAlt", bundle: .main)
  static let textPrimary = Color("textPrimary", bundle: .main)
  static let textSecondary = Color("textSecondary", bundle: .main)
  static let tintPrimary = Color("tintPrimary", bundle: .main)
  static let tintOnPrimary = Color("tintOnPrimary", bundle: .main)
  static let borderSubtle = Color("borderSubtle", bundle: .main)
  static let success = Color("success", bundle: .main)
  static let warning = Color("warning", bundle: .main)
  static let error = Color("error", bundle: .main)
}

// MARK: - Typography helpers

enum FontTokens {
  static let display = Font.system(size: 34, weight: .semibold, design: .default)
  static let title = Font.system(size: 28, weight: .semibold, design: .default)
  static let headline = Font.system(size: 20, weight: .semibold, design: .default)
  static let body = Font.system(size: 17, weight: .regular, design: .default)
  static let caption = Font.system(size: 13, weight: .regular, design: .default)
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.headline)
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
      .frame(minHeight: 44)
      .background(Tokens.tintPrimary.opacity(configuration.isPressed ? 0.85 : 1.0))
      .foregroundStyle(Tokens.tintOnPrimary)
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .stroke(Tokens.borderSubtle.opacity(0.15))
      )
      .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
  }
}

struct SecondaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.headline)
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
      .frame(minHeight: 44)
      .background(Tokens.surface)
      .foregroundStyle(Tokens.textPrimary)
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .stroke(Tokens.borderSubtle, lineWidth: 1)
      )
      .opacity(configuration.isPressed ? 0.8 : 1)
      .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
  }
}

// MARK: - Components

struct Card<Content: View>: View {
  let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    content
      .padding(12)
      .background(Tokens.surface)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(Tokens.borderSubtle, lineWidth: 1)
      )
  }
}

struct MicButton: View {
  let isRecording: Bool
  let action: () -> Void
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: action) {
      Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
        .font(.system(size: 72, weight: .regular))
        .symbolRenderingMode(.monochrome)
        .foregroundStyle(Tokens.tintPrimary)
        .accessibilityLabel(isRecording ? "Aufnahme stoppen" : "Aufnahme starten")
    }
    .buttonStyle(.plain)
    .frame(width: 88, height: 88)
    .background(
      Circle()
        .fill(Tokens.surface)
        .shadow(color: Color.black.opacity(colorScheme == .light ? 0.12 : 0), radius: 6, x: 0, y: 2)
    )
    .overlay(
      Circle()
        .stroke(Tokens.borderSubtle, lineWidth: 1)
    )
  }
}

struct ItemRow: View {
  let item: ItemEntity
  let onToggle: (() -> Void)?
  let onDelete: (() -> Void)?

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: item.status == .purchased ? "checkmark.circle" : "cart")
        .foregroundStyle(item.status == .purchased ? Tokens.success : Tokens.textSecondary)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
        Text(item.name)
          .font(.body)
          .foregroundStyle(item.status == .purchased ? Tokens.textSecondary : Tokens.textPrimary)
          .strikethrough(item.status == .purchased, color: Tokens.textSecondary)
          .lineLimit(1)
        if let note = item.detailDescription {
          Text(note)
            .font(.caption)
            .foregroundStyle(Tokens.textSecondary)
            .lineLimit(2)
        }
      }
      Spacer()
      if let q = item.formattedQuantity {
        Text(q)
          .font(.subheadline)
          .foregroundStyle(Tokens.textSecondary)
          .monospacedDigit()
      }
    }
    .padding(.vertical, 8)
    .contentShape(Rectangle())
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(item.accessibilityLabel)
    .accessibilityHint("Doppeltippen zum Markieren oder Anzeigen von Aktionen")
    .swipeActions(edge: .leading, allowsFullSwipe: true) {
      if let onToggle {
        Button(action: onToggle) {
          Label(item.status == .purchased ? "Offen" : "Erledigt", systemImage: "checkmark.circle")
        }
        .tint(Tokens.success)
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if let onDelete {
        Button(role: .destructive, action: onDelete) {
          Label("Löschen", systemImage: "trash")
        }
      }
    }
  }
}

struct Banner: View {
  enum Style {
    case info(String)
    case warning(String)
    case error(String)
  }

  let style: Style

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: iconName)
        .font(.headline)
        .foregroundStyle(iconColor)
      Text(message)
        .font(.callout)
        .foregroundStyle(Tokens.textPrimary)
        .multilineTextAlignment(.leading)
      Spacer(minLength: 12)
    }
    .padding(16)
    .background(Tokens.surfaceAlt)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(iconColor.opacity(0.3), lineWidth: 1)
    )
  }

  private var message: String {
    switch style {
    case .info(let text), .warning(let text), .error(let text):
      return text
    }
  }

  private var iconName: String {
    switch style {
    case .info:
      return "info.circle"
    case .warning:
      return "exclamationmark.triangle"
    case .error:
      return "xmark.octagon"
    }
  }

  private var iconColor: Color {
    switch style {
    case .info:
      return Tokens.tintPrimary
    case .warning:
      return Tokens.warning
    case .error:
      return Tokens.error
    }
  }
}
