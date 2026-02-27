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

            CommandGroup(after: .toolbar) {
                Menu(NSLocalizedString("Menu_Theme", comment: "")) {
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
