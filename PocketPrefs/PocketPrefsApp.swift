//
//  PocketPrefsApp.swift
//  PocketPrefs
//
//  Created by Me2 on 2025/9/17.
//

import SwiftUI

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure window appearance
        if let window = NSApplication.shared.windows.first {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.backgroundColor = NSColor.clear
        }
    }
}

// MARK: - App Entry Point

@main
struct PocketPrefsApp: App {
    @StateObject private var themeManager = ThemeManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(themeManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            // Remove default New Window command
            CommandGroup(replacing: .newItem, addition: {})

            // Add custom View menu items
            CommandGroup(after: .toolbar) {
                Menu("主题") {
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
