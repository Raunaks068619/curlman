import SwiftUI

@main
struct APIPanelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            VStack(alignment: .leading, spacing: 12) {
                Text("API Panel")
                    .font(.title2.weight(.semibold))
                Text("Use Command-Shift-C to show or hide the panel from anywhere.")
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(width: 420)
        }
    }
}

