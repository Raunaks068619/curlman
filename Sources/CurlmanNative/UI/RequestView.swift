import AppKit
import SwiftUI

struct RequestView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(RequestSection.allCases) { section in
                    Button {
                        model.requestSection = section
                    } label: {
                        Text(label(for: section))
                            .font(.system(size: 12, weight: model.requestSection == section ? .semibold : .regular))
                            .padding(.horizontal, 12)
                            .frame(height: 26)
                            .background {
                                if model.requestSection == section {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color(nsColor: .selectedContentBackgroundColor).opacity(0.22))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(model.requestSection == section ? Color.primary : Color.secondary)
                    .accessibilityAddTraits(model.requestSection == section ? .isSelected : [])
                }
                Spacer()
                if model.requestSection == .body {
                    Picker("Body type", selection: $model.draft.bodyKind) {
                        ForEach(RequestBodyKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 96)

                    if model.draft.bodyKind == .json {
                        Button(action: model.formatRequestBody) {
                            Label("Format", systemImage: "text.alignleft")
                        }
                        .buttonStyle(.borderless)
                        .keyboardShortcut("f", modifiers: [.command, .shift])

                        if !model.draft.body.isEmpty {
                            Image(systemName: model.draft.parsedJSONBody == nil ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(model.draft.parsedJSONBody == nil ? .red : .green)
                                .help(model.draft.parsedJSONBody == nil ? "Invalid JSON" : "Valid JSON")
                                .accessibilityLabel(model.draft.parsedJSONBody == nil ? "Invalid JSON" : "Valid JSON")
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Color(nsColor: .windowBackgroundColor))
            .overlay(alignment: .bottom) { Divider() }

            switch model.requestSection {
            case .body: BodyEditor(model: model)
            case .params: KeyValueEditor(title: "Query parameters", items: $model.draft.queryItems)
            case .headers: KeyValueEditor(title: "Request headers", items: $model.draft.headers)
            case .auth: AuthenticationEditor(draft: $model.draft)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func label(for section: RequestSection) -> String {
        switch section {
        case .params:
            let count = model.draft.queryItems.filter { $0.isEnabled && !$0.name.isEmpty }.count
            return count > 0 ? "Params  \(count)" : "Params"
        case .headers:
            let count = model.draft.headers.filter { $0.isEnabled && !$0.name.isEmpty }.count
            return count > 0 ? "Headers  \(count)" : "Headers"
        default:
            return section.rawValue
        }
    }
}

private struct BodyEditor: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            switch model.draft.bodyKind {
            case .none:
                VStack(spacing: 8) {
                    Image(systemName: "doc.plaintext").font(.title2).foregroundStyle(.tertiary)
                    Text("This request has no body").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .json, .raw:
                CodeTextView(
                    text: $model.draft.body,
                    placeholder: model.draft.bodyKind == .json
                        ? "{\n  \"key\": \"value\"\n}"
                        : "Enter request body"
                )
            case .formURLEncoded:
                KeyValueEditor(title: "Form fields", items: $model.draft.formItems)
            case .multipart:
                MultipartEditor(parts: $model.draft.multipartParts)
            }
        }
    }
}

struct KeyValueEditor: View {
    let title: String
    @Binding var items: [KeyValueItem]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button {
                    items.append(KeyValueItem())
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(alignment: .bottom) { Divider() }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(items.indices), id: \.self) { index in
                        HStack(spacing: 8) {
                            Toggle("", isOn: $items[index].isEnabled)
                                .labelsHidden()
                                .toggleStyle(.checkbox)
                            TextField("Name", text: $items[index].name)
                                .textFieldStyle(.roundedBorder)
                            TextField("Value", text: $items[index].value)
                                .textFieldStyle(.roundedBorder)
                            Button(role: .destructive) {
                                items.remove(at: index)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .disabled(items.count == 1)
                        }
                    }
                }
                .padding(14)
            }
        }
    }
}

private struct MultipartEditor: View {
    @Binding var parts: [MultipartPart]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Multipart fields").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button {
                    parts.append(MultipartPart())
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(alignment: .bottom) { Divider() }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(parts.indices), id: \.self) { index in
                        HStack(spacing: 8) {
                            Toggle("", isOn: $parts[index].isEnabled)
                                .labelsHidden()
                                .toggleStyle(.checkbox)
                            TextField("Name", text: $parts[index].name)
                                .textFieldStyle(.roundedBorder)
                            Picker("Kind", selection: $parts[index].kind) {
                                ForEach(MultipartPartKind.allCases) { kind in
                                    Text(kind.rawValue).tag(kind)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 74)
                            if parts[index].kind == .text {
                                TextField("Value", text: $parts[index].value)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                Button(parts[index].filePath.isEmpty ? "Choose File…" : URL(fileURLWithPath: parts[index].filePath).lastPathComponent) {
                                    chooseFile(for: index)
                                }
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Button(role: .destructive) {
                                parts.remove(at: index)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .padding(14)
            }
        }
        .onAppear {
            if parts.isEmpty { parts = [MultipartPart()] }
        }
    }

    private func chooseFile(for index: Int) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Use File"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        parts[index].filePath = url.path
        parts[index].isFileAccessApproved = true
    }
}

private struct AuthenticationEditor: View {
    @Binding var draft: HTTPRequestDraft

    var body: some View {
        Form {
            Picker("Authentication", selection: $draft.authentication.kind) {
                ForEach(AuthenticationKind.allCases) { kind in Text(kind.rawValue).tag(kind) }
            }
            .pickerStyle(.segmented)

            switch draft.authentication.kind {
            case .none:
                Text("No authentication will be added to this request.")
                    .foregroundStyle(.secondary)
            case .bearer:
                SecureField("Bearer token", text: $draft.authentication.secret)
                Text("The token is saved in macOS Keychain and excluded from history.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .basic:
                TextField("Username", text: $draft.authentication.username)
                SecureField("Password", text: $draft.authentication.secret)
                Text("The password is saved in macOS Keychain and excluded from history.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .apiKey:
                TextField("Key name", text: $draft.authentication.apiKeyName)
                SecureField("Key value", text: $draft.authentication.secret)
                Picker("Add to", selection: $draft.authentication.apiKeyPlacement) {
                    ForEach(APIKeyPlacement.allCases) { placement in
                        Text(placement.rawValue).tag(placement)
                    }
                }
                Text("The key value is saved in macOS Keychain and excluded from history.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Request behavior") {
                HStack {
                    TextField("Timeout", value: $draft.timeoutInterval, format: .number.precision(.fractionLength(0)))
                        .frame(width: 72)
                    Text("seconds")
                        .foregroundStyle(.secondary)
                }
                Picker("Redirects", selection: $draft.redirectPolicy) {
                    ForEach(RedirectPolicy.allCases) { policy in Text(policy.rawValue).tag(policy) }
                }
                Picker("Cookies", selection: $draft.cookiePolicy) {
                    ForEach(CookiePolicy.allCases) { policy in Text(policy.rawValue).tag(policy) }
                }
            }
        }
        .formStyle(.grouped)
        .padding(12)
        .frame(maxWidth: 560, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .textBackgroundColor))
    }
}
