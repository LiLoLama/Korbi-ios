import SwiftUI

struct HomeView: View {
    @StateObject var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.bgPrimary.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Spacing.large) {
                        header
                        itemsSection
                        debugSection
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 120)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: Spacing.small) {
                    if let message = viewModel.bannerState.message {
                        bannerView(for: viewModel.bannerState)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    MicButton(state: viewModel.isRecording ? .recording : .idle) {
                        viewModel.toggleRecording()
                    }
                    .padding(.bottom, 12)
                }
                .padding(.horizontal)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Überblick")
            .toolbarBackground(Tokens.bgPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear { viewModel.onAppear() }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Hallo")
                .font(Typography.caption)
                .foregroundStyle(Tokens.textSecondary)
            Text(viewModel.householdName.isEmpty ? "Haushalt" : viewModel.householdName)
                .font(Typography.display)
                .foregroundStyle(Tokens.textPrimary)
                .accessibilityLabel(Text("Haushalt: \(viewModel.householdName)"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Spacing.large)
    }

    @ViewBuilder
    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            SectionHeader(title: "Zu kaufen", buttonTitle: viewModel.items.isEmpty ? nil : "Alle anzeigen") {
                KorbiHaptics.lightImpact()
            }
            if viewModel.items.isEmpty {
                EmptyState(
                    systemImage: "cart",
                    title: "Alles erledigt",
                    message: "Gerade gibt es nichts auf deiner Liste."
                )
                .transition(.opacity)
            } else {
                VStack(spacing: Spacing.small) {
                    ForEach(viewModel.items.prefix(8)) { item in
                        Card {
                            ItemRow(
                                item: item,
                                togglePurchased: { KorbiHaptics.lightImpact() },
                                delete: { KorbiHaptics.lightImpact() }
                            )
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            SectionHeader(title: "Debug", buttonTitle: viewModel.showDebugOptions ? "Verbergen" : "Anzeigen") {
                withAnimation(.easeInOut) {
                    viewModel.showDebugOptions.toggle()
                }
            }
            if viewModel.showDebugOptions {
                VStack(alignment: .leading, spacing: Spacing.small) {
                    Toggle("Leeren Zustand simulieren", isOn: Binding(
                        get: { viewModel.simulateEmptyState },
                        set: { newValue in
                            if newValue != viewModel.simulateEmptyState {
                                viewModel.toggleEmptyState()
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .accessibilityLabel(Text("Leeren Zustand simulieren"))

                    Button("Fehler-Banner anzeigen") {
                        viewModel.triggerErrorBanner()
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button("Lade-Banner anzeigen") {
                        viewModel.startLoadingBanner()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding()
                .background(Tokens.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func bannerView(for state: BannerState) -> some View {
        switch state {
        case let .processing(message):
            Banner(style: .info, message: message) {
                viewModel.dismissBanner()
            }
        case let .success(message):
            Banner(style: .success, message: message) {
                viewModel.dismissBanner()
            }
        case let .error(message):
            Banner(style: .error, message: message) {
                viewModel.dismissBanner()
            }
        case .idle:
            EmptyView()
        }
    }
}

#Preview("HomeView") {
    HomeView(viewModel: HomeViewModel(
        householdService: HouseholdFakeService(),
        listsService: ListsFakeService(),
        itemsService: ItemsFakeService()
    ))
}
