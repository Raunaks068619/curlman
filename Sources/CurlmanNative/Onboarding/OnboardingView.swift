import AppKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var state: OnboardingState
    @ObservedObject var preferences: ShortcutPreferences
    @ObservedObject var model: AppModel
    let registerShortcut: (GlobalShortcut) -> Bool
    let metadata: BuildMetadata

    @State private var shortcutConflict: String?

    private let exampleURL = "https://api.github.com/zen"
    private let repositoryURL = URL(string: "https://github.com/Raunaks068619/curlman")!

    init(
        state: OnboardingState,
        preferences: ShortcutPreferences,
        model: AppModel,
        registerShortcut: @escaping (GlobalShortcut) -> Bool,
        metadata: BuildMetadata = BuildMetadata()
    ) {
        self.state = state
        self.preferences = preferences
        self.model = model
        self.registerShortcut = registerShortcut
        self.metadata = metadata
    }

    var body: some View {
        HStack(spacing: 0) {
            identityPanel
                .frame(width: 310)
            Divider()
            setupPanel
        }
        .background(Color(nsColor: .textBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Welcome to Curlman")
    }

    private var identityPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Curlman")
                        .font(.title3.weight(.semibold))
                    Text("Fast, local API testing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("From copied cURL to clear response in seconds.")
                .font(.system(size: 25, weight: .semibold))
                .tracking(-0.5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 28)

            Text("Call Curlman from anywhere, edit what matters, and keep every run close without opening a full API workspace.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 9)

            VStack(alignment: .leading, spacing: 17) {
                BenefitRow(icon: "command", title: "Open instantly", detail: "Use your shortcut above any app.")
                BenefitRow(icon: "arrow.up.right", title: "Paste, edit, send", detail: "Change headers, params, auth, and body.")
                BenefitRow(icon: "clock.arrow.circlepath", title: "Find it later", detail: "Every run enters local History.")
            }
            .padding(.top, 28)

            Spacer(minLength: 18)

            Label("No account. No Curlman cloud.", systemImage: "checkmark.shield")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("No account required. Requests stay on this device.")
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 30)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var setupPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("QUICK SETUP")
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(Color.accentColor)
            Text("Everything you need, on one page.")
                .font(.title2.weight(.semibold))
                .tracking(-0.3)
                .padding(.top, 6)
            Text("Confirm your shortcut, optionally try a safe request, then start using Curlman.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 5)

            SectionLabel(title: "Global shortcut", note: "Click the keys to change")
                .padding(.top, 23)
            shortcutControl

            SectionLabel(title: "Try your first request", note: "Nothing sends automatically")
                .padding(.top, 19)
            exampleRequest

            githubCard
                .padding(.top, 20)

            Spacer(minLength: 16)
            Divider()
                .padding(.bottom, 15)
            HStack {
                Text("Reopen this anytime from Help.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Start Using Curlman") { state.complete() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityHint("Closes welcome and opens the request workspace")
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 27)
        .padding(.bottom, 22)
    }

    private var shortcutControl: some View {
        HStack(spacing: 10) {
            Image(systemName: "command")
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text("Show or hide Curlman from anywhere")
                    .font(.callout.weight(.medium))
                if let shortcutConflict {
                    Text(shortcutConflict)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else {
                    Text("No Accessibility permission needed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            ShortcutRecorder(shortcut: preferences.shortcut, onCapture: applyShortcut)
                .frame(width: 104, height: 27)
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        }
    }

    private var exampleRequest: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Text("GET")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 48)
                Text(exampleURL)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(model.isSending ? "Cancel" : "Send") { sendExample() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 10)
            .frame(height: 40)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            }

            Label(exampleStatus, systemImage: exampleStatusIcon)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .accessibilityLabel(exampleStatus)
        }
    }

    private var githubCard: some View {
        HStack(spacing: 11) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Raunaks068619/curlman")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(1)
                Text(GitHubStarCopy.supporting(metadata.githubStars))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Label(GitHubStarCopy.count(metadata.githubStars), systemImage: "star.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.yellow)
                .padding(.horizontal, 9)
                .frame(height: 28)
                .background(Color.yellow.opacity(0.12), in: Capsule())
            Button {
                NSWorkspace.shared.open(repositoryURL)
            } label: {
                Label("Star on GitHub", systemImage: "star")
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Opens the public Curlman repository in your browser")
        }
        .padding(.horizontal, 12)
        .frame(height: 64)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        }
    }

    private var exampleStatus: String {
        if model.isSending { return "Sending request…" }
        guard let response = model.response else {
            return "Press Command-Return. Curlman saves the result to History."
        }
        if response.isTransportFailure {
            return "Attempt saved to History. You can retry when the network is available."
        }
        return "Response \(response.statusLabel) saved to History."
    }

    private var exampleStatusIcon: String {
        if model.isSending { return "arrow.triangle.2.circlepath" }
        return model.response == nil ? "return" : "checkmark.circle.fill"
    }

    private func applyShortcut(_ shortcut: GlobalShortcut) {
        guard registerShortcut(shortcut) else {
            shortcutConflict = "That shortcut is already in use."
            return
        }
        preferences.save(shortcut)
        shortcutConflict = nil
    }

    private func sendExample() {
        if model.isSending {
            model.send()
            return
        }
        model.importCurl("curl \(exampleURL)")
        model.send()
    }
}

private struct BenefitRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SectionLabel: View {
    let title: String
    let note: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption.weight(.semibold))
            Spacer()
            Text(note)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 7)
    }
}
