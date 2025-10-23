import SwiftUI

struct MicButton: View {
    enum State {
        case idle
        case recording
    }

    let state: State
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: state == .recording ? "stop.circle.fill" : "mic.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundStyle(state == .recording ? Tokens.error : Tokens.tintPrimary)
                .symbolEffect(.bounce.down, options: state == .recording ? .repeating : .default)
                .padding(Spacing.small)
                .background(
                    Circle()
                        .fill(Tokens.surface)
                        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state == .recording ? Text("Aufnahme stoppen") : Text("Aufnahme starten"))
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("MicButton") {
    VStack(spacing: 20) {
        MicButton(state: .idle, action: {})
        MicButton(state: .recording, action: {})
    }
    .padding()
    .background(Tokens.bgPrimary)
}
