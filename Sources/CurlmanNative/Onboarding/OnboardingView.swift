import AppKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var state: OnboardingState
    @ObservedObject var preferences: ShortcutPreferences
    @ObservedObject var model: AppModel
    let registerShortcut: (GlobalShortcut) -> Bool
    let metadata: BuildMetadata

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                if state.page == .introduction {
                    introductionPage.transition(pageTransition(forward: false))
                } else {
                    setupPage.transition(pageTransition(forward: true))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .clipped()

            footer
        }
        .background(Color(nsColor: .textBackgroundColor))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: state.page)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Curlman setup, page \(state.page.rawValue + 1) of 2")
    }

    private var introductionPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 13) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Curlman").font(.system(size: 19, weight: .semibold))
                    Text("Fast, local API testing").font(.system(size: 13)).foregroundStyle(.secondary)
                }
            }

            Text("cURL in. Clear answers out.")
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.4)
                .padding(.top, 24)

            Text("Call Curlman from anywhere, edit what matters, and keep every run close without opening a full API workspace.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            HStack(alignment: .top, spacing: 22) {
                Benefit(icon: "command", title: "Open instantly", detail: "Use your shortcut above any app.")
                Benefit(icon: "arrow.up.right", title: "Paste, edit, send", detail: "Change the complete request.")
                Benefit(icon: "clock.arrow.circlepath", title: "Local history", detail: "Every run is saved locally.")
            }
            .padding(.top, 26)

            githubCard.padding(.top, 26)

            Label("No account. No Curlman cloud.", systemImage: "checkmark.shield")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .padding(.top, 14)
        }
        .frame(width: 600, alignment: .leading)
    }

    private var setupPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("QUICK SETUP")
                .font(.system(size: 12.5, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Color.accentColor)
            Text("Ready in under a minute.")
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.3)
                .padding(.top, 8)
            Text("Choose how Curlman opens, then optionally send one safe request.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            SectionLabel(title: "Global shortcut", note: "Click the keys to change")
                .padding(.top, 32)
            shortcutControl

            SectionLabel(title: "Try your first request", note: "Nothing sends automatically")
                .padding(.top, 28)
            exampleRequest

        }
        .frame(width: 600, alignment: .leading)
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(OnboardingPage.allCases, id: \.rawValue) { page in
                    Circle()
                        .fill(page == state.page ? Color.accentColor : Color.secondary.opacity(0.28))
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityLabel("Page \(state.page.rawValue + 1) of 2")

            Spacer()

            if state.page == .setup {
                Button("Back") { state.returnToIntroduction() }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
            }
            Button(state.page == .introduction ? "Continue" : "Start Using Curlman") {
                if state.page == .introduction { state.continueToSetup() }
                else { state.complete() }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 24)
        .frame(height: 52)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) { Divider() }
    }

    private var shortcutControl: some View {
        HStack(spacing: 10) {
            Image(systemName: "command")
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text("Show or hide Curlman from anywhere").font(.system(size: 14, weight: .medium))
                Text(shortcutConflict ?? "No Accessibility permission needed")
                    .font(.system(size: 12))
                    .foregroundStyle(shortcutConflict == nil ? Color.secondary : Color.orange)
            }
            Spacer()
            ShortcutRecorder(shortcut: preferences.shortcut, onCapture: applyShortcut)
                .frame(width: 104, height: 27)
        }
        .padding(.horizontal, 12)
        .frame(height: 58)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
        .overlay { RoundedRectangle(cornerRadius: 9).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5) }
    }

    private var exampleRequest: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text("GET")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.blue)
                    .frame(width: 42)
                Text(exampleURL)
                    .font(.system(size: 13, design: .monospaced))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(model.isSending ? "Cancel" : "Send") { sendExample() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 11)
            .frame(height: 48)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5) }

            Label(exampleStatus, systemImage: exampleStatusIcon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .accessibilityLabel(exampleStatus)
        }
    }

    private var githubCard: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable().scaledToFit().frame(width: 36, height: 36).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Raunaks068619/curlman")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.accentColor)
                Text(GitHubStarCopy.supporting(metadata.githubStars))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Label(GitHubStarCopy.count(metadata.githubStars), systemImage: "star.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.yellow)
            Button { NSWorkspace.shared.open(repositoryURL) } label: {
                Label("Star on GitHub", systemImage: "star")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 12)
        .frame(height: 66)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
        .overlay { RoundedRectangle(cornerRadius: 9).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5) }
    }

    private var exampleStatus: String {
        if model.isSending { return "Sending request…" }
        guard let response = model.response else { return "Press Command-Return. The result will be saved to History." }
        if response.isTransportFailure { return "Attempt saved to History. Retry when the network is available." }
        return "Response \(response.statusLabel) saved to History."
    }

    private var exampleStatusIcon: String {
        model.isSending ? "arrow.triangle.2.circlepath" : (model.response == nil ? "return" : "checkmark.circle.fill")
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
        if model.isSending { model.send(); return }
        model.importCurl("curl \(exampleURL)")
        model.send()
    }

    private func pageTransition(forward: Bool) -> AnyTransition {
        guard !reduceMotion else { return .identity }
        return .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
        )
    }
}

private struct Benefit: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13.5, weight: .semibold))
                Text(detail).font(.system(size: 12.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SectionLabel: View {
    let title: String
    let note: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 13.5, weight: .semibold))
            Spacer()
            Text(note).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .padding(.bottom, 9)
    }
}
