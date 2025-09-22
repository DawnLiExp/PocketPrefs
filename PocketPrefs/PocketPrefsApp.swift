//
//  PocketPrefsApp.swift
//  PocketPrefs
//
//  App entry point and main window configuration
//

import SwiftUI

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure window appearance after launch
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                // Make titlebar blend with content but not fully transparent
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.styleMask.insert(.fullSizeContentView)
                
                // Remove toolbar separator
                window.toolbarStyle = .unified
                
                // Enable window dragging from background
                window.isMovableByWindowBackground = true
                
                // Don't set backgroundColor to clear - let SwiftUI handle the background
                // This ensures the window has proper background color
                // window.backgroundColor = NSColor.clear  // REMOVED
                
                // Set minimum window size
                window.minSize = NSSize(
                    width: DesignConstants.Layout.minWindowWidth,
                    height: DesignConstants.Layout.minWindowHeight
                )
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Custom Window Background

struct WindowBackgroundView: NSViewRepresentable {
    @Environment(\.colorScheme) var colorScheme
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        updateBackground(view)
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        updateBackground(nsView)
    }
    
    private func updateBackground(_ view: NSView) {
        DispatchQueue.main.async {
            if let window = view.window {
                // Apply visual effect view for proper background
                window.titlebarAppearsTransparent = true
                
                // Set background based on color scheme
                if colorScheme == .dark {
                    window.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 0.95)
                } else {
                    window.backgroundColor = NSColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 0.95)
                }
            }
        }
    }
}

// MARK: - App Entry Point

@main
struct PocketPrefsApp: App {
    @StateObject private var themeManager = ThemeManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.colorScheme) var colorScheme

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Window background handler
                WindowBackgroundView()
                    .ignoresSafeArea()
                
                // Main content
                MainView()
                    .environmentObject(themeManager)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            // Remove default New Window command
            CommandGroup(replacing: .newItem, addition: {})

            // Add custom View menu items
            CommandGroup(after: .toolbar) {
                Menu(NSLocalizedString("Menu_Theme", comment: "")) {
                    ForEach(Theme.allCases, id: \.self) { theme in
                        Button(action: { themeManager.setTheme(theme) }) {
                            HStack {
                                Text(theme.displayName)
                                if themeManager.currentTheme == theme {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
