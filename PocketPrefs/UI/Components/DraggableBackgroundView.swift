//
//  DraggableBackgroundView.swift
//  PocketPrefs
//
//  Enables window dragging for background areas
//

import SwiftUI

struct DraggableBackgroundView: NSViewRepresentable {
    func makeNSView(context: Context) -> DraggableNSView {
        DraggableNSView()
    }

    func updateNSView(_ nsView: DraggableNSView, context: Context) {}
}

class DraggableNSView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        true
    }
}
