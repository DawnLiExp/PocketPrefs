//
//  PocketPrefsApp.swift
//  PocketPrefs
//
//  App entry point with enhanced glass effect integration and structured concurrency
//

import os.log
import SwiftUI

// MARK: - App Delegate

/// Handles application lifecycle events and enhanced window configuration
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            await configureMainWindow()
        }
    }
    
    /// Configure main window with enhanced glass effect integration
    private func configureMainWindow() async {
        guard let window = NSApplication.shared.windows.first else {
            // Retry with exponential backoff if window not ready
            try? await Task.sleep(for: .milliseconds(100))
            guard let window = NSApplication.shared.windows.first else { return }
            await applyEnhancedWindowConfiguration(to: window)
            return
        }
        
        await applyEnhancedWindowConfiguration(to: window)
    }
    
    /// Apply enhanced window configuration for glass effect unity
    private func applyEnhancedWindowConfiguration(to window: NSWindow) async {
        // Enhanced title bar configuration for glass effect unity
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.toolbarStyle = .unified
        window.isOpaque = false
        
        // Enhanced background blur for title bar integration
        window.hasShadow = true
        window.invalidateShadow()
        
        // Set minimum window size
        window.minSize = NSSize(
            width: DesignConstants.Layout.minWindowWidth,
            height: DesignConstants.Layout.minWindowHeight
        )
        
        // Configure for glass effect compatibility
        window.collectionBehavior = [.fullScreenPrimary]
        window.animationBehavior = .documentWindow
    }

    /// Terminate application when last window closes
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

// MARK: - Enhanced Window Background

/// Enhanced window background view with improved glass effect integration
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

/// Enhanced NSView for window background with glass effect management
@MainActor
class EnhancedWindowBackgroundNSView: NSView {
    private var colorScheme: ColorScheme
    private var updateTask: Task<Void, Never>?
    
    init(colorScheme: ColorScheme) {
        self.colorScheme = colorScheme
        super.init(frame: .zero)
        
        Task {
            await configureEnhancedBackground()
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        updateTask?.cancel()
    }
    
    /// Configure enhanced background with glass effect support
    private func configureEnhancedBackground() async {
        var attempts = 0
        while window == nil && attempts < 10 {
            try? await Task.sleep(for: .milliseconds(50))
            attempts += 1
        }
        
        guard let window = window else { return }
        await applyEnhancedBackgroundColor(to: window)
    }
    
    /// Update background with enhanced glass effect integration
    func updateBackground(colorScheme: ColorScheme) async {
        updateTask?.cancel()
        
        self.colorScheme = colorScheme
        
        updateTask = Task { @MainActor in
            guard !Task.isCancelled,
                  let window = self.window else { return }
            
            await self.applyEnhancedBackgroundColor(to: window)
        }
        
        await updateTask?.value
    }
    
    /// Apply enhanced background for glass effect unity
    private func applyEnhancedBackgroundColor(to window: NSWindow) async {
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        
        // Enhanced background colors for better glass effect integration
        let backgroundColor: NSColor
        
        switch colorScheme {
        case .dark:
            backgroundColor = NSColor(
                red: 0.267, green: 0.267, blue: 0.306, alpha: 0.72
            ) // #44444E with 72% opacity
        default:
            backgroundColor = NSColor(
                red: 0.961, green: 0.949, blue: 0.929, alpha: 0.72
            ) // #F5F2ED with 72% opacity
        }
        
        window.backgroundColor = backgroundColor
        
        // Enhanced window effects for glass integration
        await configureWindowEffects(window)
    }
    
    /// Configure additional window effects for glass integration
    private func configureWindowEffects(_ window: NSWindow) async {
        // Enable window shadow for depth
        window.hasShadow = true
        
        // Configure level for proper layering
        window.level = .normal
        
        // Invalidate shadow to apply changes
        window.invalidateShadow()
    }
}

// MARK: - Window Configuration Actor

/// Thread-safe window configuration management
actor WindowConfigurator {
    static let shared = WindowConfigurator()
    
    private init() {}
    
    func configureWindow(_ window: NSWindow, for colorScheme: ColorScheme) {
        Task { @MainActor in
            window.titlebarAppearsTransparent = true
            window.isOpaque = false
            
            let backgroundColor: NSColor = switch colorScheme {
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

// MARK: - Enhanced App Entry Point

@main
struct PocketPrefsApp: App {
    @StateObject private var themeManager = ThemeManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.colorScheme) var colorScheme

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Enhanced window background with glass effect
                EnhancedWindowBackgroundView()
                    .ignoresSafeArea(.all)

                // Main content with glass effect integration
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
            // Remove default New Window command
            CommandGroup(replacing: .newItem, addition: {})

            // Enhanced View menu with theme selection
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
    
    /// Initialize app with structured concurrency
    @MainActor
    private func initializeApp() async {
        logger.info("PocketPrefs initializing with enhanced glass effects")
        
        // Additional initialization can be added here
        await configureGlobalEffects()
    }
    
    /// Configure global visual effects
    @MainActor
    private func configureGlobalEffects() async {
        // Configure any global visual effects here
        // This is where additional glass effect configuration would go
    }
    
    /// Change theme with enhanced effects
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
