import SwiftUI
import Foundation

enum KorbiTheme {
    enum Metrics {
        static let cornerRadius: CGFloat = 24
        static let compactCornerRadius: CGFloat = 18
        static let cardPadding: CGFloat = 20
        static let cardSpacing: CGFloat = 18
        static let shadowRadius: CGFloat = 18
    }

    enum Typography {
        static func largeTitle(weight: Font.Weight = .semibold) -> Font {
            .system(size: 34, weight: weight, design: .rounded)
        }

        static func title(weight: Font.Weight = .semibold) -> Font {
            .system(size: 24, weight: weight, design: .rounded)
        }

        static func body(weight: Font.Weight = .regular) -> Font {
            .system(size: 17, weight: weight, design: .default)
        }

        static func caption(weight: Font.Weight = .medium) -> Font {
            .system(size: 13, weight: weight, design: .rounded)
        }
    }
}

struct KorbiBackground: View {
    @EnvironmentObject private var settings: KorbiSettings

    var body: some View {
        GeometryReader { geometry in
            let gradient = LinearGradient(
                colors: settings.backgroundGradient,
                startPoint: .top,
                endPoint: .bottom
            )

            gradient
                .overlay(
                    Circle()
                        .fill(settings.palette.accent.opacity(settings.useWarmLightMode ? 0.35 : 0.25))
                        .blur(radius: settings.useWarmLightMode ? 160 : 120)
                        .frame(width: geometry.size.width * 0.8)
                        .offset(x: geometry.size.width * 0.35, y: -geometry.size.height * 0.15)
                )
                .overlay(
                    Circle()
                        .fill(settings.palette.primary.opacity(settings.useWarmLightMode ? 0.12 : 0.08))
                        .blur(radius: settings.useWarmLightMode ? 180 : 160)
                        .frame(width: geometry.size.width * 0.9)
                        .offset(x: -geometry.size.width * 0.4, y: geometry.size.height * 0.55)
                )
                .ignoresSafeArea()
        }
    }
}

struct KorbiCard<Content: View>: View {
    @EnvironmentObject private var settings: KorbiSettings
    let spacing: CGFloat
    @ViewBuilder var content: Content

    init(spacing: CGFloat = KorbiTheme.Metrics.cardSpacing, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .padding(KorbiTheme.Metrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: KorbiTheme.Metrics.cornerRadius, style: .continuous)
                .fill(settings.palette.card)
                .shadow(color: Color.black.opacity(settings.useWarmLightMode ? 0.05 : 0.08), radius: KorbiTheme.Metrics.shadowRadius, x: 0, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KorbiTheme.Metrics.cornerRadius, style: .continuous)
                .stroke(settings.palette.outline.opacity(settings.useWarmLightMode ? 0.5 : 0.4), lineWidth: 1)
        )
    }
}

struct PillTag: View {
    @EnvironmentObject private var settings: KorbiSettings
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(KorbiTheme.Typography.caption())
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(settings.palette.accent.opacity(0.35))
            )
            .foregroundStyle(settings.palette.primary)
    }
}

struct FloatingMicButton: View {
    @EnvironmentObject private var settings: KorbiSettings
    private let providedWebhookURL: URL?
    @StateObject private var recorder = VoiceRecorder()
    @State private var isPulsing = false

    private var activeWebhookURL: URL {
        providedWebhookURL ?? settings.voiceRecordingWebhookURL
    }

    private var pulseAnimation: Animation {
        .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
    }

    init(webhookURL: URL? = nil) {
        self.providedWebhookURL = webhookURL
    }

    var body: some View {
        VStack(spacing: 12) {
            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(backgroundFill)
                        .scaleEffect(recorder.isRecording && isPulsing ? 1.12 : 1.0)
                        .shadow(color: shadowColor, radius: 20, x: 0, y: 18)

                    if recorder.isSending {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 84, height: 84)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(recorder.isRecording ? "Aufnahme stoppen" : "Aufnahme starten")
            .disabled(recorder.isSending)
            .onChange(of: recorder.isRecording) { _, recording in
                if recording {
                    withAnimation(pulseAnimation) { isPulsing = true }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { isPulsing = false }
                }
            }

            feedbackMessages
        }
        .onAppear(perform: configureRecorder)
        .onChange(of: providedWebhookURL) { configureRecorder() }
        .onChange(of: settings.voiceRecordingWebhookURL) { configureRecorder() }
        .onChange(of: settings.currentHousehold?.id) { configureRecorder() }
    }

    private var backgroundFill: LinearGradient {
        if recorder.isRecording {
            return LinearGradient(
                colors: [Color.red, Color.red.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [settings.palette.primary, settings.palette.primary.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var shadowColor: Color {
        recorder.isRecording
            ? Color.red.opacity(0.4)
            : settings.palette.primary.opacity(0.35)
    }

    private var feedbackMessages: some View {
        VStack(spacing: 6) {
            if let success = recorder.successMessage {
                feedbackLabel(text: success, foreground: .white, background: settings.palette.primary)
            }

            if let error = recorder.errorMessage {
                feedbackLabel(text: error, foreground: .white, background: Color.red)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: recorder.successMessage)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: recorder.errorMessage)
    }

    private func feedbackLabel(text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(KorbiTheme.Typography.caption())
            .foregroundStyle(foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(background.opacity(0.92))
            )
            .shadow(color: background.opacity(0.2), radius: 12, x: 0, y: 6)
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func toggleRecording() {
        if recorder.isRecording {
            recorder.stopRecording()
        } else {
            configureRecorder()
            recorder.startRecording()
        }
    }

    private func configureRecorder() {
        recorder.configure(
            webhookURL: activeWebhookURL,
            householdID: settings.currentHousehold?.id,
            onWebhookDone: {
                Task {
                    await settings.refreshActiveSession()
                }
            }
        )
    }
}
