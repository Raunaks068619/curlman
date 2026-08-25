import SwiftUI

struct ShortcutSettingsView: View {
    @ObservedObject var preferences: ShortcutPreferences
    let register: (GlobalShortcut) -> Bool

    @State private var conflictMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Curlman")
                    .font(.title2.weight(.semibold))
                Text("Choose the global shortcut that shows or hides the request panel.")
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Global shortcut")
                        .fontWeight(.medium)
                    Text("Click the shortcut, then press a new key combination.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 24)
                ShortcutRecorder(shortcut: preferences.shortcut, onCapture: apply)
                    .frame(width: 112, height: 28)
                Button("Reset") { apply(.defaultShortcut) }
            }

            if let conflictMessage {
                Label(conflictMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Shortcut conflict. \(conflictMessage)")
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 520, height: 210)
    }

    private func apply(_ shortcut: GlobalShortcut) {
        guard register(shortcut) else {
            conflictMessage = "That shortcut is already used by another application."
            return
        }
        preferences.save(shortcut)
        conflictMessage = nil
    }
}
