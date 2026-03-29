//
//  PocketPrefsApp.swift
//  PocketPrefs
//
//  App entry point with theme commands
//

import os.log
import SwiftUI

@main
struct PocketPrefsApp: App {
    @State private var themeManager = ThemeManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let logger = Logger(subsystem: "com.pocketprefs", category: "App")

    init() {
        // Apply stored language preference early
        if let stored = UserDefaults.standard.string(forKey: "PocketPrefsLanguage"),
           !stored.isEmpty
        {
            UserDefaults.standard.set([stored], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }
    }

    var body: some Scene {
        // MARK: - Main Window

        WindowGroup {
            ZStack {
                WindowBackgroundView()
                    .ignoresSafeArea(.all)

                MainView()
            }
            .task {
                logger.info("PocketPrefs initializing")
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem, addition: {})

            CommandGroup(replacing: .appSettings) {
                Button(String(localized: "Settings_Title", defaultValue: "Settings...")) {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(after: .toolbar) {
                Menu(String(localized: "Menu_Theme", defaultValue: "Theme")) {
                    ForEach(Theme.allCases, id: \.self) { theme in
                        Button(action: {
                            changeTheme(to: theme)
                        }) {
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

        // MARK: - Settings Window

        //
        // Independent secondary window — avoids the modal sheet blocking main window drag.
        // openWindow(id: "settings", value: true) is deduplicated: same value brings the
        // existing window to front rather than opening a second instance.
        // Sync stays intact: all @Observable singletons are shared within the process;
        // onDisappear in SettingsWindowView still fires SettingsEventPublisher.publishDidClose().

        WindowGroup(id: "settings", for: Bool.self) { _ in
            SettingsWindowView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    @MainActor
    private func changeTheme(to theme: Theme) {
        withAnimation(DesignConstants.Animation.smooth) {
            themeManager.setTheme(theme)
        }
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .frame(width: 900, height: 600)
}
