//
//  PocketPrefsApp.swift
//  PocketPrefs
//
//  App entry point and main window configuration
//

import os.log
import SwiftUI

// MARK: - App Delegate

/// Handles application lifecycle events and window configuration
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure window appearance after launch using structured concurrency
        Task {
            await configureMainWindow()
        }
    }
    
    /// Configure main window appearance
    private func configureMainWindow() async {
        guard let window = NSApplication.shared.windows.first else {
            // Retry after a short delay if window not ready
            try? await Task.sleep(for: .milliseconds(100))
            guard let window = NSApplication.shared.windows.first else { return }
            await applyWindowConfiguration(to: window)
            return
        }
        
        await applyWindowConfiguration(to: window)
    }
    
    /// Apply window configuration settings
    private func applyWindowConfiguration(to window: NSWindow) async {
        // Unified toolbar appearance
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.toolbarStyle = .unified
        
        // Set minimum window size
        window.minSize = NSSize(
            width: DesignConstants.Layout.minWindowWidth,
            height: DesignConstants.Layout.minWindowHeight
        )
    }

    /// Terminate application when last window closes
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

// MARK: - Custom Window Background

/// Manages window background appearance with color scheme adaptation
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

/// Custom NSView for window background management
@MainActor
class WindowBackgroundNSView: NSView {
    private var colorScheme: ColorScheme
    private var updateTask: Task<Void, Never>?
    
    init(colorScheme: ColorScheme) {
        self.colorScheme = colorScheme
        super.init(frame: .zero)
        
        // Initial configuration
        Task {
            await configureBackground()
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        updateTask?.cancel()
    }
    
    /// Configure initial background
    private func configureBackground() async {
        // Wait for window to be available
        var attempts = 0
        while window == nil && attempts < 10 {
            try? await Task.sleep(for: .milliseconds(50))
            attempts += 1
        }
        
        guard let window = window else { return }
        applyBackgroundColor(to: window)
    }
    
    /// Update background with new color scheme
    func updateBackground(colorScheme: ColorScheme) async {
        // Cancel any pending update
        updateTask?.cancel()
        
        self.colorScheme = colorScheme
        
        // Create new update task with structured concurrency
        updateTask = Task { @MainActor in
            guard !Task.isCancelled,
                  let window = self.window else { return }
            
            self.applyBackgroundColor(to: window)
        }
        
        await updateTask?.value
    }
    
    /// Apply color scheme-appropriate background
    private func applyBackgroundColor(to window: NSWindow) {
        window.titlebarAppearsTransparent = true
        
        // Set background based on color scheme
        window.backgroundColor = colorScheme == .dark
            ? NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 0.95)
            : NSColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 0.95)
    }
}

// MARK: - Window Configuration Actor

/// Actor for managing window configuration in a thread-safe manner
actor WindowConfigurator {
    static let shared = WindowConfigurator()
    
    private init() {}
    
    func configureWindow(_ window: NSWindow, for colorScheme: ColorScheme) {
        Task { @MainActor in
            window.titlebarAppearsTransparent = true
            window.backgroundColor = colorScheme == .dark
                ? NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 0.95)
                : NSColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 0.95)
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
            .task {
                // Perform any async initialization here
                await initializeApp()
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
                        Button(action: {
                            Task { @MainActor in
                                themeManager.setTheme(theme)
                            }
                        }) {
                            HStack {
                                Text(theme.displayName)
                                // Show checkmark for current theme
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
    
    /// Initialize app components using structured concurrency
    @MainActor
    private func initializeApp() async {
        // Perform any necessary async initialization
        // This is called once when the app starts
        logger.info("PocketPrefs initialized with structured concurrency")
    }
    
    private let logger = Logger(subsystem: "com.pocketprefs", category: "App")
}
