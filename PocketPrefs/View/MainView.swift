//
//  MainView.swift
//  PocketPrefs
//
//  Main container view with three-column layout
//

import SwiftUI

struct MainView: View {
    @StateObject private var backupManager = BackupManager()
    @StateObject private var themeManager = ThemeManager.shared
    @State private var currentMode: AppMode = .backup
    @State private var selectedApp: AppConfig?
    @State private var showingRestorePicker = false
    @State private var isProcessing = false
    @State private var progress: Double = 0.0
    @Environment(\.colorScheme) var colorScheme
    
    // Unified spacing - titlebar height serves as visual spacing
    private let unifiedSpacing: CGFloat = 13
    private let sidebarGap: CGFloat = 0 // Smaller gap to sidebar for visual balance
    
    enum AppMode: String {
        case backup
        case restore
        
        var displayName: String {
            switch self {
            case .backup: return NSLocalizedString("MainView_Mode_Backup", comment: "")
            case .restore: return NSLocalizedString("MainView_Mode_Restore", comment: "")
            }
        }

        var icon: String {
            switch self {
            case .backup: return "gearshape.arrow.trianglehead.2.clockwise.rotate.90"
            case .restore: return "clock.arrow.trianglehead.2.counterclockwise.rotate.90"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Full background with glass effect
            Color.clear
                .unifiedBackground()
                .ignoresSafeArea()
            
            // Content area with merged middle and right sections
            HStack(spacing: 0) {
                // Left Sidebar
                SidebarView(currentMode: $currentMode)
                    .frame(width: DesignConstants.Layout.sidebarWidth)
                
                // Merged middle and right content area
                HStack(spacing: 0) {
                    // Middle Content Area
                    Group {
                        if currentMode == .backup {
                            AppListView(
                                backupManager: backupManager,
                                selectedApp: $selectedApp,
                                currentMode: currentMode
                            )
                        } else {
                            RestoreListView(
                                backupManager: backupManager,
                                selectedApp: $selectedApp
                            )
                        }
                    }
                    .frame(
                        minWidth: DesignConstants.Layout.listWidth,
                        idealWidth: DesignConstants.Layout.listWidth,
                        maxWidth: DesignConstants.Layout.listWidth + 60
                    )
                    .background(Color.App.contentAreaBackground.color(for: colorScheme))
                    
                    // Divider between middle and right sections
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(.ultraThinMaterial)
                        .frame(width: 1)
                        .background(Color.App.lightSeparator.color(for: colorScheme).opacity(0.3))
                    
                    // Right Detail Area
                    DetailContainerView(
                        selectedApp: selectedApp,
                        backupManager: backupManager,
                        currentMode: currentMode,
                        isProcessing: $isProcessing,
                        progress: $progress,
                        showingRestorePicker: $showingRestorePicker
                    )
                    .frame(maxWidth: .infinity)
                    .background(Color.App.contentAreaBackground.color(for: colorScheme))
                }
                .clipShape(RoundedRectangle(cornerRadius: DesignConstants.Layout.cornerRadius))
                .shadow(
                    color: colorScheme == .dark
                        ? Color.black.opacity(0.3)
                        : Color.black.opacity(0.08),
                    radius: 4,
                    x: 0,
                    y: 2
                )
                .padding(.leading, sidebarGap)
                .padding(.trailing, unifiedSpacing)
                .padding(.bottom, unifiedSpacing)
            }
        }
        .frame(
            minWidth: DesignConstants.Layout.minWindowWidth,
            minHeight: DesignConstants.Layout.minWindowHeight
        )
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
        .fileImporter(
            isPresented: $showingRestorePicker,
            allowedContentTypes: [.directory],
            allowsMultipleSelection: false
        ) { result in
            handleRestorePicker(result: result)
        }
    }
    
    private func handleRestorePicker(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                withAnimation(DesignConstants.Animation.standard) {
                    isProcessing = true
                    progress = 0.0
                }
                
                Task { @MainActor in
                    while progress < 0.9 {
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        progress += 0.02
                    }
                    
                    backupManager.performRestore(from: url.path)
                    
                    progress = 1.0
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    isProcessing = false
                    progress = 0.0
                }
            }
        case .failure(let error):
            backupManager.statusMessage = String(
                format: NSLocalizedString("Error_Select_Backup_Failed", comment: ""),
                error.localizedDescription
            )
        }
    }
}
