//  WindowBackgroundView.swift
//  PocketPrefs
//
//  Window background configuration with adaptive colors
//

import SwiftUI

struct WindowBackgroundView: NSViewRepresentable {
    @Environment(\.colorScheme) var colorScheme

    func makeNSView(context: Context) -> WindowBackgroundNSView {
        WindowBackgroundNSView(colorScheme: colorScheme)
    }

    func updateNSView(_ nsView: WindowBackgroundNSView, context: Context) {
        Task { @MainActor in
            await nsView.updateBackground(colorScheme: colorScheme)
        }
    }
}

@MainActor
class WindowBackgroundNSView: NSView {
    private var colorScheme: ColorScheme
    private var updateTask: Task<Void, Never>?
    
    init(colorScheme: ColorScheme) {
        self.colorScheme = colorScheme
        super.init(frame: .zero)
        
        Task {
            await configureBackground()
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    deinit {
        updateTask?.cancel()
    }
    
    private func configureBackground() async {
        var attempts = 0
        while window == nil, attempts < 10 {
            try? await Task.sleep(for: .milliseconds(50))
            attempts += 1
        }
        
        guard let window else { return }
        await applyBackgroundColor(to: window)
    }
    
    func updateBackground(colorScheme: ColorScheme) async {
        updateTask?.cancel()
        self.colorScheme = colorScheme
        
        updateTask = Task { @MainActor in
            guard !Task.isCancelled, let window = self.window else { return }
            await self.applyBackgroundColor(to: window)
        }
        
        await updateTask?.value
    }
    
    private func applyBackgroundColor(to window: NSWindow) async {
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        
        let backgroundColor = Color.App.windowBackground.nsColor(for: colorScheme)
        
        window.backgroundColor = backgroundColor
        window.hasShadow = true
        window.invalidateShadow()
    }
}
