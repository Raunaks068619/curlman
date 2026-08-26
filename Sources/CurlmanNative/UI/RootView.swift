import AppKit
import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel
    let closeAction: () -> Void
    let minimizeAction: () -> Void
    let dragAction: (NSEvent) -> Void

    var body: some View {
        Group {
            if model.isCompact {
                CompactPanelView(
                    model: model,
                    closeAction: closeAction,
                    restoreAction: minimizeAction
                )
            } else {
                VStack(spacing: 0) {
                    PanelTitleBar(
                        closeAction: closeAction,
                        minimizeAction: minimizeAction,
                        dragAction: dragAction
                    )
                    RequestCommandBar(model: model)
                    TopTabBar(model: model)
                    if let error = model.inlineError {
                        InlineMessage(text: error, systemImage: "exclamationmark.triangle.fill", color: .orange)
                    } else if !model.curlWarnings.isEmpty {
                        InlineMessage(text: model.curlWarnings.joined(separator: "  "), systemImage: "info.circle.fill", color: .secondary)
                    }
                    activeContent
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.65), lineWidth: 0.5)
        }
        .ignoresSafeArea()
        .onExitCommand(perform: closeAction)
    }

    @ViewBuilder
    private var activeContent: some View {
        switch model.selectedTab {
        case .request:
            RequestView(model: model)
        case .response:
            if let response = model.response {
                ResponseView(model: model, response: response)
            } else {
                RequestView(model: model)
            }
        case .history:
            HistoryView(model: model)
        }
    }
}

private struct PanelTitleBar: View {
    let closeAction: () -> Void
    let minimizeAction: () -> Void
    let dragAction: (NSEvent) -> Void

    var body: some View {
        ZStack {
            WindowDragRegion(dragAction: dragAction)

            HStack(spacing: 8) {
                WindowControl(color: .red, symbol: "xmark", help: "Close to menu bar", action: closeAction)
                WindowControl(color: .yellow, symbol: "minus", help: "Minimize to command strip", action: minimizeAction)
                Spacer()
                Text("Curlman")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
                Spacer()
                Image(systemName: "menubar.rectangle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 32)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 36)
        .background(.ultraThinMaterial)
    }
}

private struct RequestCommandBar: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            Picker("Method", selection: $model.draft.method) {
                ForEach(HTTPMethod.allCases) { method in Text(method.rawValue).tag(method) }
            }
            .labelsHidden()
            .frame(width: 94)

            CurlTextField(
                value: model.draft.urlString,
                placeholder: "Enter URL or paste a curl request",
                onChange: model.updateURLInput,
                onCurlPaste: model.importCurl
            )
            .frame(height: 24)
            .accessibilityLabel("Request URL or curl command")

            Button(action: model.copyAsCurl) {
                HStack(spacing: 5) {
                    Image(systemName: model.didCopyCurl ? "checkmark" : "doc.on.doc")
                    Text(model.didCopyCurl ? "Copied" : "Copy cURL")
                }
                .frame(minWidth: 76)
            }
            .buttonStyle(.bordered)
            .help("Copy the current edited request as cURL")
            .accessibilityLabel(model.didCopyCurl ? "cURL copied" : "Copy current request as cURL")

            Button(action: model.send) {
                HStack(spacing: 6) {
                    if model.isSending {
                        ProgressView().controlSize(.small)
                        Text("Cancel")
                    } else {
                        Text("Send")
                        Text("⌘↵")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: 72)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 12)
        .frame(height: 50)
        .background(.thinMaterial)
    }
}

private struct WindowControl: View {
    let color: Color
    let symbol: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(color)
                if hovering {
                    Image(systemName: symbol)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.55))
                }
            }
            .frame(width: 12, height: 12)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

private struct TopTabBar: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 4) {
            ForEach(model.availableTabs) { tab in
                Button {
                    model.selectedTab = tab
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: icon(for: tab))
                        Text(label(for: tab))
                    }
                    .font(.system(size: 12, weight: model.selectedTab == tab ? .semibold : .regular))
                    .padding(.horizontal, 11)
                    .frame(height: 26)
                    .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .background {
                        if model.selectedTab == tab {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.accentColor.opacity(0.16))
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(model.selectedTab == tab ? Color.accentColor : Color.secondary)
                .accessibilityAddTraits(model.selectedTab == tab ? .isSelected : [])
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) { Divider() }
    }

    private func label(for tab: TopTab) -> String {
        if tab == .response, let status = model.response?.statusCode {
            return "Response  \(status)"
        }
        return tab.rawValue
    }

    private func icon(for tab: TopTab) -> String {
        switch tab {
        case .request: return "arrow.up.right"
        case .response: return "arrow.down.left"
        case .history: return "clock.arrow.circlepath"
        }
    }
}

private struct InlineMessage: View {
    let text: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage).foregroundStyle(color)
            Text(text).font(.caption).textSelection(.enabled)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) { Divider() }
    }
}

private struct CompactPanelView: View {
    @ObservedObject var model: AppModel
    let closeAction: () -> Void
    let restoreAction: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            WindowControl(color: .red, symbol: "xmark", help: "Close to menu bar", action: closeAction)
            WindowControl(color: .yellow, symbol: "plus", help: "Restore panel", action: restoreAction)
            Picker("Method", selection: $model.draft.method) {
                ForEach(HTTPMethod.allCases) { method in
                    Text(method.rawValue).tag(method)
                }
            }
            .labelsHidden()
            .frame(width: 76)

            CurlTextField(
                value: model.draft.urlString,
                placeholder: "Paste URL or curl…",
                onChange: model.updateURLInput,
                onCurlPaste: { command in
                    model.importCurl(command)
                    restoreAction()
                }
            )
            .frame(maxWidth: .infinity)
            .frame(height: 23)
            .accessibilityLabel("Compact request URL or curl command")

            Button {
                model.send()
                restoreAction()
            } label: {
                Image(systemName: model.isSending ? "stop.fill" : "paperplane.fill")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.return, modifiers: .command)
            .help(model.isSending ? "Cancel request" : "Send request (Command-Return)")
        }
        .padding(.horizontal, 12)
        .background(.regularMaterial)
    }
}
