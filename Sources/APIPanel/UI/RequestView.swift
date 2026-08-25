import SwiftUI

struct RequestView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Request section", selection: $model.requestSection) {
                    ForEach(RequestSection.allCases) { section in
                        Text(label(for: section)).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 430)
                Spacer()
                if model.requestSection == .body, model.draft.bodyKind == .json {
                    Button("Format", action: model.formatRequestBody)
                        .keyboardShortcut("f", modifiers: [.command, .shift])
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
            case .auth: AuthenticationEditor(authentication: $model.draft.authentication)
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
        VStack(spacing: 0) {
            HStack {
                Picker("Body type", selection: $model.draft.bodyKind) {
                    ForEach(RequestBodyKind.allCases) { kind in Text(kind.rawValue).tag(kind) }
                }
                .labelsHidden()
                .frame(width: 110)
                Spacer()
                if model.draft.bodyKind == .json, !model.draft.body.isEmpty {
                    Label(model.draft.parsedJSONBody == nil ? "Invalid JSON" : "Valid JSON",
                          systemImage: model.draft.parsedJSONBody == nil ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(model.draft.parsedJSONBody == nil ? .red : .green)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(alignment: .bottom) { Divider() }

            if model.draft.bodyKind == .none {
                VStack(spacing: 8) {
                    Image(systemName: "doc.plaintext").font(.title2).foregroundStyle(.tertiary)
                    Text("This request has no body").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                CodeTextView(
                    text: $model.draft.body,
                    placeholder: model.draft.bodyKind == .json
                        ? "{\n  \"key\": \"value\"\n}"
                        : "Enter request body"
                )
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

private struct AuthenticationEditor: View {
    @Binding var authentication: Authentication

    var body: some View {
        Form {
            Picker("Authentication", selection: $authentication.kind) {
                ForEach(AuthenticationKind.allCases) { kind in Text(kind.rawValue).tag(kind) }
            }
            .pickerStyle(.segmented)

            switch authentication.kind {
            case .none:
                Text("No authentication will be added to this request.")
                    .foregroundStyle(.secondary)
            case .bearer:
                SecureField("Bearer token", text: $authentication.secret)
                Text("The token is saved in macOS Keychain and excluded from history.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .basic:
                TextField("Username", text: $authentication.username)
                SecureField("Password", text: $authentication.secret)
                Text("The password is saved in macOS Keychain and excluded from history.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(12)
        .frame(maxWidth: 560, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .textBackgroundColor))
    }
}
