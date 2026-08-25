import AppKit
import SwiftUI

struct CodeTextView: View {
    @Binding var text: String
    var isEditable = true
    var placeholder = ""

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 12.5, design: .monospaced))
                .scrollContentBackground(.hidden)
                .disabled(!isEditable)
                .textSelection(.enabled)
                .padding(.horizontal, 9)
                .padding(.vertical, 8)

            if text.isEmpty, !placeholder.isEmpty {
                Text(placeholder)
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .accessibilityLabel(isEditable ? "Request body editor" : "Response viewer")
    }
}
