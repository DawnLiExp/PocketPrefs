//
//  NonDraggableView.swift
//  PocketPrefs
//
//  Prevents window dragging in specific view areas
//

import SwiftUI

struct NonDraggableView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(NonDraggableBackgroundView())
    }
}

struct NonDraggableBackgroundView: NSViewRepresentable {
    func makeNSView(context: Context) -> NonDraggableNSView {
        NonDraggableNSView()
    }

    func updateNSView(_ nsView: NonDraggableNSView, context: Context) {}
}

class NonDraggableNSView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        false
    }
}
