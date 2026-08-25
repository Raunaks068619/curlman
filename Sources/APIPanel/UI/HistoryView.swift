import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: AppModel
    @State private var showClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search name, URL, method or status", text: $model.historySearch)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 360)
                Spacer()
                Text("\(model.filteredHistory.count) requests")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Clear…", role: .destructive) { showClearConfirmation = true }
                    .disabled(model.historyStore.records.isEmpty)
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Color(nsColor: .windowBackgroundColor))
            .overlay(alignment: .bottom) { Divider() }

            if model.filteredHistory.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath").font(.title).foregroundStyle(.tertiary)
                    Text(model.historySearch.isEmpty ? "No requests yet" : "No matching requests")
                        .font(.headline)
                    Text(model.historySearch.isEmpty ? "Every executed request will appear here automatically." : "Try a different method, URL, name, or status.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.filteredHistory) { record in
                    HistoryRow(
                        record: record,
                        restore: { model.restore(record) },
                        openResponse: { model.openStoredResponse(record) },
                        togglePin: { model.togglePin(record) },
                        delete: { model.deleteHistory(record) }
                    )
                }
                .listStyle(.inset)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .confirmationDialog("Clear all history?", isPresented: $showClearConfirmation) {
            Button("Clear All History", role: .destructive, action: model.clearHistory)
        } message: {
            Text("This removes all stored requests and responses. Keychain credentials are not removed.")
        }
    }
}

private struct HistoryRow: View {
    let record: HistoryRecord
    let restore: () -> Void
    let openResponse: () -> Void
    let togglePin: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(record.method)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(methodColor)
                .frame(width: 52, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.displayName.isEmpty ? record.urlString : record.displayName)
                    .font(.body)
                    .lineLimit(1)
                if !record.displayName.isEmpty {
                    Text(record.urlString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(statusText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(statusColor)
                .frame(width: 54, alignment: .trailing)
            if record.completedAt != nil {
                Text(record.duration, format: .number.precision(.fractionLength(0...2)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .trailing)
            }
            Text(record.startedAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .trailing)
            Button(action: togglePin) {
                Image(systemName: record.isPinned ? "star.fill" : "star")
                    .foregroundStyle(record.isPinned ? .yellow : .secondary)
            }
            .buttonStyle(.borderless)
            .help(record.isPinned ? "Unpin" : "Pin")
            Menu {
                Button("Restore Request", action: restore)
                if record.response != nil { Button("Open Response", action: openResponse) }
                Divider()
                Button("Delete", role: .destructive, action: delete)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: restore)
    }

    private var statusText: String {
        if let statusCode = record.statusCode { return "\(statusCode)" }
        switch record.outcome {
        case .pending: return "Running"
        case .cancelled: return "Stopped"
        case .transportFailure: return "Failed"
        default: return "—"
        }
    }

    private var statusColor: Color {
        guard let statusCode = record.statusCode else {
            return record.outcome == .pending ? .secondary : .red
        }
        if statusCode < 300 { return .green }
        if statusCode < 400 { return .orange }
        return .red
    }

    private var methodColor: Color {
        switch record.method {
        case "GET": return .blue
        case "POST": return .green
        case "DELETE": return .red
        case "PUT", "PATCH": return .orange
        default: return .secondary
        }
    }
}

