import SwiftUI

struct OnboardingView: View {
    @ObservedObject var state: OnboardingState
    @ObservedObject var preferences: ShortcutPreferences
    @ObservedObject var model: AppModel
    let registerShortcut: (GlobalShortcut) -> Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shortcutConflict: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                    Circle()
                        .fill(step.rawValue <= state.currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                }
                Spacer()
                Button("Skip") { state.complete() }
                    .buttonStyle(.borderless)
                    .accessibilityHint("Closes onboarding without sending a request")
            }
            .padding(.horizontal, 18)
            .frame(height: 40)

            Group {
                switch state.currentStep {
                case .welcome:
                    welcome
                case .shortcut:
                    shortcut
                case .request:
                    exampleRequest
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: state.currentStep)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Curlman welcome, step \(state.currentStep.rawValue + 1) of 3")
    }

    private var welcome: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)
            VStack(spacing: 7) {
                Text("Paste cURL. Test it. Find it later.")
                    .font(.title2.weight(.semibold))
                Text("Curlman stays in your menu bar, needs no account, and keeps request history on this Mac.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 430)
            }
            Button("Set Up Curlman") { state.continueFromWelcome() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        }
        .padding(28)
    }

    private var shortcut: some View {
        VStack(spacing: 20) {
            Image(systemName: "command")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            VStack(spacing: 7) {
                Text("Open Curlman from anywhere")
                    .font(.title2.weight(.semibold))
                Text("Press the shortcut to hide this panel, then press it again to bring Curlman back.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 430)
            }
            HStack(spacing: 10) {
                Text("Global shortcut")
                    .fontWeight(.medium)
                ShortcutRecorder(shortcut: preferences.shortcut, onCapture: applyShortcut)
                    .frame(width: 112, height: 28)
            }
            if let shortcutConflict {
                Label(shortcutConflict, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            } else if state.didHideWithShortcut {
                Label("Shortcut detected. Press \(preferences.shortcut.displayName) once more.", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Label("Waiting for \(preferences.shortcut.displayName)", systemImage: "keyboard")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(28)
    }

    private var exampleRequest: some View {
        VStack(spacing: 18) {
            Image(systemName: model.response == nil ? "paperplane" : "checkmark.circle.fill")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(model.response == nil ? Color.accentColor : .green)
                .accessibilityHidden(true)
            VStack(spacing: 7) {
                Text(model.response == nil ? "Send your first request" : "You’re ready")
                    .font(.title2.weight(.semibold))
                Text(exampleDescription)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }
            Text("curl https://api.github.com/zen")
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 7))

            if model.response == nil {
                Button(model.isSending ? "Cancel Request" : "Send Example") {
                    model.send()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: .command)
            } else {
                Button("Start Using Curlman") { state.complete() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .onAppear(perform: loadExampleIfNeeded)
    }

    private var exampleDescription: String {
        guard let response = model.response else {
            return "The request is ready. Press Command-Return or choose Send Example. Curlman will save the result to History automatically."
        }
        if response.isTransportFailure {
            return "The network did not respond, but Curlman captured the attempt in History. You can retry it later."
        }
        return "Response \(response.statusLabel) is saved in History."
    }

    private func applyShortcut(_ shortcut: GlobalShortcut) {
        guard registerShortcut(shortcut) else {
            shortcutConflict = "That shortcut is already used by another application."
            return
        }
        preferences.save(shortcut)
        shortcutConflict = nil
    }

    private func loadExampleIfNeeded() {
        guard model.response == nil,
              model.draft.urlString != "https://api.github.com/zen" else { return }
        model.importCurl("curl https://api.github.com/zen")
    }
}
