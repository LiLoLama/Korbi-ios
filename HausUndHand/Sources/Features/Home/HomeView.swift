import SwiftUI

struct HomeView: View {
  @ObservedObject var viewModel: HomeViewModel
  @EnvironmentObject private var appState: AppState

  var body: some View {
    NavigationStack {
      ZStack(alignment: .bottomTrailing) {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            header
            if let banner = viewModel.banner {
              Banner(style: banner)
            }
            quickAddCard
            itemsSection
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 120)
        }
        MicButton(isRecording: isRecording, action: micTapped)
          .padding(24)
      }
      .background(Tokens.bgPrimary.ignoresSafeArea())
      .navigationTitle("Home")
      .toolbar { toolbarContent }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(appState.households.first(where: { $0.id == appState.activeHouseholdID })?.name ?? "Mein Haushalt")
        .font(FontTokens.title)
        .foregroundStyle(Tokens.textPrimary)
      Text("Zu kaufen")
        .font(FontTokens.headline)
        .foregroundStyle(Tokens.textSecondary)
    }
  }

  private var quickAddCard: some View {
    Card {
      VStack(alignment: .leading, spacing: 12) {
        Text("Schnell hinzufügen")
          .font(FontTokens.headline)
          .foregroundStyle(Tokens.textPrimary)
        HStack {
          TextField("Was fehlt?", text: $viewModel.quickAddText)
            .textFieldStyle(.plain)
            .submitLabel(.done)
            .onSubmit { viewModel.addQuickItem() }
          Button(action: viewModel.addQuickItem) {
            Image(systemName: "plus.circle.fill")
              .font(.title3)
              .foregroundStyle(Tokens.tintPrimary)
          }
          .accessibilityLabel("Artikel hinzufügen")
        }
      }
    }
  }

  private var itemsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      if viewModel.items.isEmpty {
        EmptyStateView()
      } else {
        Card {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(viewModel.items) { item in
              ItemRow(item: item, onToggle: { viewModel.togglePurchased(item: item) }, onDelete: { viewModel.delete(item: item) })
              if item.id != viewModel.items.last?.id {
                Divider().background(Tokens.borderSubtle)
              }
            }
          }
        }
      }
    }
  }

  private var isRecording: Bool {
    if case .recording = appState.voiceState.phase {
      return true
    }
    return false
  }

  private func micTapped() {
    if isRecording {
      viewModel.stopRecording()
    } else if let userID = appState.session?.userID {
      viewModel.startRecording(userID: userID)
    }
  }

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    ToolbarItem(placement: .navigationBarTrailing) {
      Menu {
        Picker("Haushalt", selection: $appState.activeHouseholdID) {
          ForEach(appState.households) { household in
            Text(household.name).tag(Optional(household.id))
          }
        }
      } label: {
        Image(systemName: "arrowtriangle.down.circle")
          .foregroundStyle(Tokens.textSecondary)
      }
    }
  }
}

private struct EmptyStateView: View {
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "takeoutbag.and.cup.and.straw")
        .font(.system(size: 48))
        .foregroundStyle(Tokens.textSecondary)
      Text("Alles erledigt!")
        .font(FontTokens.headline)
        .foregroundStyle(Tokens.textPrimary)
      Text("Füge neue Artikel hinzu oder nutze die Sprachaufnahme.")
        .font(FontTokens.body)
        .foregroundStyle(Tokens.textSecondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(32)
    .background(Tokens.surfaceAlt)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}
