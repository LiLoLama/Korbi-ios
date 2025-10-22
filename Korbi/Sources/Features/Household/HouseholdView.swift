import SwiftUI
import CoreImage.CIFilterBuiltins

struct HouseholdView: View {
  @StateObject private var viewModel: HouseholdViewModel
  @EnvironmentObject private var appState: AppState
  @State private var joinCode: String = ""
  private let context = CIContext()
  private let filter = CIFilter.qrCodeGenerator()

  init(viewModel: HouseholdViewModel) {
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          membersSection
          inviteSection
          joinSection
        }
        .padding(20)
      }
      .background(Tokens.bgPrimary.ignoresSafeArea())
      .navigationTitle("Haushalt")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button(action: viewModel.refresh) {
            Image(systemName: "arrow.clockwise")
          }
        }
      }
      .onAppear(perform: viewModel.refresh)
      .alert("Fehler", isPresented: Binding(
        get: { viewModel.errorMessage != nil },
        set: { _ in viewModel.errorMessage = nil }
      ), actions: {
        Button("OK", role: .cancel) {}
      }, message: {
        Text(viewModel.errorMessage ?? "Unbekannter Fehler")
      })
    }
  }

  private var membersSection: some View {
    Card {
      VStack(alignment: .leading, spacing: 12) {
        Text("Mitglieder")
          .font(FontTokens.headline)
          .foregroundStyle(Tokens.textPrimary)
        ForEach(viewModel.members) { member in
          HStack {
            Image(systemName: "person.crop.circle")
              .foregroundStyle(Tokens.textSecondary)
            VStack(alignment: .leading) {
              Text(member.displayName ?? "Unbekannt")
                .font(FontTokens.body)
                .foregroundStyle(Tokens.textPrimary)
              Text(member.role.localizedTitle)
                .font(FontTokens.caption)
                .foregroundStyle(Tokens.textSecondary)
            }
            Spacer()
          }
          .padding(.vertical, 4)
          Divider().opacity(member.id == viewModel.members.last?.id ? 0 : 1)
        }
      }
    }
  }

  private var inviteSection: some View {
    Card {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text("Einladung teilen")
            .font(FontTokens.headline)
            .foregroundStyle(Tokens.textPrimary)
          Spacer()
          Button("QR erzeugen") { viewModel.generateInvite() }
            .buttonStyle(SecondaryButtonStyle())
        }

        if let invite = viewModel.invite, let qrImage = qrImage(for: invite.url.absoluteString) {
          VStack(spacing: 12) {
            Image(uiImage: qrImage)
              .interpolation(.none)
              .resizable()
              .frame(width: 160, height: 160)
              .accessibilityLabel("QR-Code Einladung")
            Text(invite.url.absoluteString)
              .font(FontTokens.caption)
              .foregroundStyle(Tokens.textSecondary)
              .textSelection(.enabled)
            ShareLink(item: invite.url) {
              Label("Link teilen", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(PrimaryButtonStyle())
          }
          .frame(maxWidth: .infinity)
        } else {
          Text("Tippe auf 'QR erzeugen', um eine Einladung zu erstellen.")
            .font(FontTokens.body)
            .foregroundStyle(Tokens.textSecondary)
        }
      }
    }
  }

  private var joinSection: some View {
    Card {
      VStack(alignment: .leading, spacing: 12) {
        Text("Haushalt beitreten")
          .font(FontTokens.headline)
        TextField("Invite Token", text: $joinCode)
          .textContentType(.oneTimeCode)
          .padding()
          .background(Tokens.surface)
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          .overlay(RoundedRectangle(cornerRadius: 12).stroke(Tokens.borderSubtle))
        Button("Beitreten") { viewModel.join(tokenString: joinCode) }
          .buttonStyle(PrimaryButtonStyle())
      }
    }
  }

  private func qrImage(for string: String) -> UIImage? {
    let data = Data(string.utf8)
    filter.setValue(data, forKey: "inputMessage")
    guard let outputImage = filter.outputImage else { return nil }
    if let cgImage = context.createCGImage(outputImage.transformed(by: CGAffineTransform(scaleX: 8, y: 8)), from: outputImage.extent) {
      return UIImage(cgImage: cgImage)
    }
    return nil
  }
}
