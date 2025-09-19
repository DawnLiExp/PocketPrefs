//
//  MainView.swift
//  PocketPrefs
//
//  Created by Me2 on 2025/9/18.
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
            case .backup: return "duffle.bag.fill"
            case .restore: return "clock.arrow.trianglehead.2.counterclockwise.rotate.90"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar - Fixed width, no interaction
            SidebarView(currentMode: $currentMode)
                .frame(width: DesignConstants.Layout.sidebarWidth)
                .background(Color(NSColor.windowBackgroundColor))
            
            // Separator line
            Divider()
                .background(Color(NSColor.separatorColor))
            
            // Middle Content
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
                minWidth: DesignConstants.Layout.listWidth - 20,
                idealWidth: DesignConstants.Layout.listWidth,
                maxWidth: DesignConstants.Layout.listWidth + 60
            )
            .background(Color(NSColor.controlBackgroundColor))
            
            // Separator line
            Divider()
                .background(Color(NSColor.separatorColor))
            
            // Right Detail - Takes remaining space
            DetailContainerView(
                selectedApp: selectedApp,
                backupManager: backupManager,
                currentMode: currentMode,
                isProcessing: $isProcessing,
                progress: $progress,
                showingRestorePicker: $showingRestorePicker
            )
            .frame(maxWidth: .infinity)
            .background(Color.App.background)
        }
        .background(Color.App.background)
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
            backupManager.statusMessage = "选择备份失败: \(error.localizedDescription)"
        }
    }
}
