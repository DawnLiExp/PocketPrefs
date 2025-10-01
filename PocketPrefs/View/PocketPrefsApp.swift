//
//  PocketPrefsApp.swift
//  PocketPrefs
//
//  App entry point with structured concurrency and glass effects
//

import os.log
import SwiftUI

// MARK: - App Delegate

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

// MARK: - Window Background

struct EnhancedWindowBackgroundView: NSViewRepresentable {
    @Environment(\.colorScheme) var colorScheme

    func makeNSView(context: Context) -> EnhancedWindowBackgroundNSView {
        EnhancedWindowBackgroundNSView(colorScheme: colorScheme)
    }

    func updateNSView(_ nsView: EnhancedWindowBackgroundNSView, context: Context) {
        Task { @MainActor in
            await nsView.updateBackground(colorScheme: colorScheme)
        }
    }
}

@MainActor
class EnhancedWindowBackgroundNSView: NSView {
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
            guard !Task.isCancelled,
                  let window = self.window else { return }
            
            await self.applyBackgroundColor(to: window)
        }
        
        await updateTask?.value
    }
    
    private func applyBackgroundColor(to window: NSWindow) async {
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        
        let backgroundColor = switch colorScheme {
        case .dark:
            NSColor(red: 0.267, green: 0.267, blue: 0.306, alpha: 0.68)
        default:
            NSColor(red: 0.961, green: 0.949, blue: 0.929, alpha: 0.70)
        }
        
        window.backgroundColor = backgroundColor
        
        await configureWindowEffects(window)
    }
    
    private func configureWindowEffects(_ window: NSWindow) async {
        window.hasShadow = true
        window.level = .normal
        window.invalidateShadow()
    }
}

// MARK: - Window Configurator

actor WindowConfigurator {
    static let shared = WindowConfigurator()
    
    private init() {}
    
    func configureWindow(_ window: NSWindow, for colorScheme: ColorScheme) {
        Task { @MainActor in
            window.titlebarAppearsTransparent = true
            window.isOpaque = false
            
            let backgroundColor = switch colorScheme {
            case .dark:
                NSColor(red: 0.267, green: 0.267, blue: 0.306, alpha: 0.72)
            default:
                NSColor(red: 0.961, green: 0.949, blue: 0.929, alpha: 0.72)
            }
            
            window.backgroundColor = backgroundColor
            window.hasShadow = true
            window.invalidateShadow()
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
                EnhancedWindowBackgroundView()
                    .ignoresSafeArea(.all)

                MainView()
                    .environmentObject(themeManager)
            }
            .task {
                await initializeApp()
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
    private func initializeApp() async {
        logger.info("PocketPrefs initializing")
        await configureGlobalEffects()
    }
    
    @MainActor
    private func configureGlobalEffects() async {
        // Global visual effects configuration
    }
    
    @MainActor
    private func changeTheme(to theme: Theme) {
        withAnimation(DesignConstants.Animation.smooth) {
            themeManager.setTheme(theme)
        }
    }
    
    private let logger = Logger(subsystem: "com.pocketprefs", category: "App")
}

// MARK: - Preview

#Preview {
    MainView()
        .frame(width: 900, height: 600)
}
