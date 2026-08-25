import AppKit
import SwiftUI

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
    }
}

struct WindowDragRegion: NSViewRepresentable {
    let dragAction: (NSEvent) -> Void

    func makeNSView(context: Context) -> DragView {
        DragView(action: dragAction)
    }

    func updateNSView(_ view: DragView, context: Context) {
        view.action = dragAction
    }

    final class DragView: NSView {
        var action: (NSEvent) -> Void

        init(action: @escaping (NSEvent) -> Void) {
            self.action = action
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func mouseDown(with event: NSEvent) {
            action(event)
        }
    }
}

