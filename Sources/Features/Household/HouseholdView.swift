import SwiftUI

struct HouseholdView: View {
    @StateObject var viewModel: HouseholdViewModel
    @State private var showInviteSheet = false

    init(viewModel: HouseholdViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Tokens.bgPrimary.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.large) {
                        header
                        membersList
                    }
                    .padding()
                }
                if case let .error(message) = viewModel.bannerState {
                    Banner(style: .error, message: message) {
                        viewModel.bannerState = .idle
                    }
                    .padding()
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationTitle("Haushalt")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showInviteSheet = true
                    } label: {
                        Label("Einladen", systemImage: "qrcode")
                    }
                    .accessibilityLabel(Text("Mitglied einladen"))
                }
            }
        }
        .sheet(isPresented: $showInviteSheet) {
            inviteSheet
        }
        .onAppear { viewModel.onAppear() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(viewModel.household?.name ?? "Haushalt")
                .font(Typography.title)
                .foregroundStyle(Tokens.textPrimary)
            Text("\(viewModel.members.count) Mitglieder")
                .font(Typography.body)
                .foregroundStyle(Tokens.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var membersList: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            SectionHeader(title: "Mitglieder")
            VStack(spacing: Spacing.small) {
                ForEach(viewModel.members) { member in
                    Card {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(member.name)
                                    .font(Typography.headline)
                                    .foregroundStyle(Tokens.textPrimary)
                                Text(member.role.rawValue)
                                    .font(Typography.caption)
                                    .foregroundStyle(Tokens.textSecondary)
                            }
                            Spacer()
                            Image(systemName: member.role == .owner ? "star.fill" : "person")
                                .foregroundStyle(Tokens.tintPrimary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Text("\(member.name), Rolle: \(member.role.rawValue)"))
                    }
                }
            }
        }
    }

    private var inviteSheet: some View {
        NavigationStack {
            VStack(spacing: Spacing.large) {
                Image(systemName: "qrcode")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .foregroundStyle(Tokens.tintPrimary)
                    .korbiShadow()
                Text("QR-Code Platzhalter")
                    .font(Typography.headline)
                Text("Teile den Code, um neue Mitglieder einzuladen. Funktion folgt später.")
                    .font(Typography.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Tokens.textSecondary)
                PrimaryButton("Link kopieren") {
                    KorbiHaptics.lightImpact()
                }
                .padding(.horizontal)
                Spacer()
            }
            .padding()
            .background(Tokens.bgPrimary)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") {
                        showInviteSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview("HouseholdView") {
    HouseholdView(viewModel: HouseholdViewModel(service: HouseholdFakeService()))
}
