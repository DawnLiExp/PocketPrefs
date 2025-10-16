//
//  AppDelegate.swift
//  PocketPrefs
//
//  Application lifecycle and window configuration
//

import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            await configureMainWindow()
        }
    }
    
    private func configureMainWindow() async {
        guard let window = NSApplication.shared.windows.first else {
            try? await Task.sleep(for: .milliseconds(100))
            guard let window = NSApplication.shared.windows.first else { return }
            await applyWindowConfiguration(to: window)
            return
        }
        
        await applyWindowConfiguration(to: window)
    }
    
    private func applyWindowConfiguration(to window: NSWindow) async {
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.toolbarStyle = .unified
        window.isOpaque = false
        window.isMovableByWindowBackground = true
        window.hasShadow = true
        window.invalidateShadow()
        
        window.minSize = NSSize(
            width: DesignConstants.Layout.minWindowWidth,
            height: DesignConstants.Layout.minWindowHeight,
        )
        
        window.collectionBehavior = [.fullScreenPrimary]
        window.animationBehavior = .documentWindow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
