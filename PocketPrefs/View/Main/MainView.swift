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
    
    // Layout constants
    private enum Layout {
        static let unifiedSpacing: CGFloat = 13
        static let sidebarGap: CGFloat = 0
    }
    
    enum AppMode: String, CaseIterable {
        case backup
        case restore
        
        var displayName: String {
            switch self {
            case .backup:
                return NSLocalizedString("MainView_Mode_Backup", comment: "")
            case .restore:
                return NSLocalizedString("MainView_Mode_Restore", comment: "")
            }
        }

        var icon: String {
            switch self {
            case .backup:
                return "gearshape.arrow.trianglehead.2.clockwise.rotate.90"
            case .restore:
                return "clock.arrow.trianglehead.2.counterclockwise.rotate.90"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Full background with glass effect
            Color.clear
                .unifiedBackground()
                .ignoresSafeArea()
            
            // Content area
            HStack(spacing: 0) {
                // Left Sidebar
                SidebarView(currentMode: $currentMode)
                    .frame(width: DesignConstants.Layout.sidebarWidth)
                
                // Main content area
                contentArea
                    .clipShape(RoundedRectangle(cornerRadius: DesignConstants.Layout.cornerRadius))
                    .shadow(
                        color: shadowColor,
                        radius: 4,
                        x: 0,
                        y: 2
                    )
                    .padding(.leading, Layout.sidebarGap)
                    .padding(.trailing, Layout.unifiedSpacing)
                    .padding(.bottom, Layout.unifiedSpacing)
            }
        }
        .frame(
            minWidth: DesignConstants.Layout.minWindowWidth,
            minHeight: DesignConstants.Layout.minWindowHeight
        )
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
    }
    
    @ViewBuilder
    private var contentArea: some View {
        HStack(spacing: 0) {
            // Middle list area
            listView
                .frame(
                    minWidth: DesignConstants.Layout.listWidth,
                    idealWidth: DesignConstants.Layout.listWidth,
                    maxWidth: DesignConstants.Layout.listWidth + 60
                )
                .background(backgroundColor)
            
            // Divider
            RoundedRectangle(cornerRadius: 0.5)
                .fill(.ultraThinMaterial)
                .frame(width: 1)
                .background(dividerColor)
            
            // Right detail area - using the existing DetailContainerView
            DetailContainerView(
                selectedApp: selectedApp,
                backupManager: backupManager,
                currentMode: currentMode,
                isProcessing: $isProcessing,
                progress: $progress,
                showingRestorePicker: $showingRestorePicker
            )
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
        }
    }
    
    @ViewBuilder
    private var listView: some View {
        switch currentMode {
        case .backup:
            AppListView(
                backupManager: backupManager,
                selectedApp: $selectedApp,
                currentMode: currentMode
            )
        case .restore:
            RestoreListView(
                backupManager: backupManager,
                selectedApp: $selectedApp
            )
        }
    }
    
    private var backgroundColor: Color {
        Color.App.contentAreaBackground.color(for: colorScheme)
    }
    
    private var shadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.3)
            : Color.black.opacity(0.08)
    }
    
    private var dividerColor: Color {
        Color.App.lightSeparator
            .color(for: colorScheme)
            .opacity(0.3)
    }
}
