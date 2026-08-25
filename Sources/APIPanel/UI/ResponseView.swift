import SwiftUI

struct ResponseView: View {
    @ObservedObject var model: AppModel
    let response: HTTPResponseSnapshot
    @State private var responseSearch = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Label(response.statusLabel, systemImage: statusSymbol)
                    .font(.headline)
                    .foregroundStyle(statusColor)
                Text(response.duration, format: .number.precision(.fractionLength(0...3)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(ByteCountFormatter.string(fromByteCount: Int64(response.receivedByteCount), countStyle: .file))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(displayedText, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                Button {
                    saveResponse()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(alignment: .bottom) { Divider() }

            HStack {
                Picker("Response view", selection: $model.responseSection) {
                    Text("Pretty").tag(ResponseSection.pretty)
                    Text("Raw").tag(ResponseSection.raw)
                    Text("Headers  \(response.headers.count)").tag(ResponseSection.headers)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 340)
                Spacer()
                TextField("Find in response", text: $responseSearch)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 190)
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(Color(nsColor: .windowBackgroundColor))
            .overlay(alignment: .bottom) { Divider() }

            CodeTextView(text: .constant(displayedText), isEditable: false)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var displayedText: String {
        switch model.responseSection {
        case .pretty: return response.prettyBodyText
        case .raw: return response.bodyText
        case .headers:
            return response.headers.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
                .map { "\($0.key): \($0.value)" }
                .joined(separator: "\n")
        }
    }

    private var statusColor: Color {
        guard let code = response.statusCode else { return response.wasCancelled ? .secondary : .red }
        if code < 300 { return .green }
        if code < 400 { return .orange }
        return .red
    }

    private var statusSymbol: String {
        guard response.statusCode != nil else { return response.wasCancelled ? "stop.circle.fill" : "exclamationmark.triangle.fill" }
        return "circle.fill"
    }

    private func saveResponse() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = response.mimeType?.contains("json") == true ? "response.json" : "response.txt"
        if panel.runModal() == .OK, let url = panel.url {
            try? response.body.write(to: url)
        }
    }
}

