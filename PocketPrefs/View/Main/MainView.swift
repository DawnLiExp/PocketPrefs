//
//  MainView.swift
//  PocketPrefs
//
//  Main container view with three-column layout and enhanced glass effects
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
    
    // Layout constants optimized for glass effect visibility
    private enum Layout {
        static let unifiedSpacing: CGFloat = 13
        static let sidebarGap: CGFloat = 0
        static let topPadding: CGFloat = 0 // No top padding to blend with title bar
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
            // Enhanced unified background with glass effect
            Color.clear
                .unifiedBackground()
                .ignoresSafeArea(.all)
            
            // Main content container
            contentContainer
        }
        .frame(
            minWidth: DesignConstants.Layout.minWindowWidth,
            minHeight: DesignConstants.Layout.minWindowHeight
        )
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
    }
    
    @ViewBuilder
    private var contentContainer: some View {
        HStack(spacing: Layout.sidebarGap) {
            // Enhanced sidebar with glass effect
            enhancedSidebar
                .frame(width: DesignConstants.Layout.sidebarWidth)
            
            // Main content area with floating effect
            floatingContentArea
                .padding(.trailing, Layout.unifiedSpacing)
                .padding(.bottom, Layout.unifiedSpacing)
                .padding(.top, Layout.topPadding)
        }
    }
    
    @ViewBuilder
    private var enhancedSidebar: some View {
        SidebarView(currentMode: $currentMode)
            .frame(maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var floatingContentArea: some View {
        HStack(spacing: 0) {
            // Middle list area
            listView
                .frame(
                    minWidth: DesignConstants.Layout.listWidth,
                    idealWidth: DesignConstants.Layout.listWidth,
                    maxWidth: DesignConstants.Layout.listWidth + 60
                )
                .background(contentAreaBackgroundColor)
            
            // Subtle content divider
            contentDivider
            
            // Right detail area
            DetailContainerView(
                selectedApp: selectedApp,
                backupManager: backupManager,
                currentMode: currentMode,
                isProcessing: $isProcessing,
                progress: $progress,
                showingRestorePicker: $showingRestorePicker
            )
            .frame(maxWidth: .infinity)
            .background(contentAreaBackgroundColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.Layout.cornerRadius))
        .shadow(
            color: shadowColor,
            radius: 5,
            x: 0,
            y: 2
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignConstants.Layout.cornerRadius)
                .stroke(
                    Color.App.contentAreaBorder.color(for: colorScheme),
                    lineWidth: DesignConstants.Layout.contentAreaBorderWidth
                )
        )
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
    
    @ViewBuilder
    private var contentDivider: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .fill(
                        Color.App.lightSeparator
                            .color(for: colorScheme)
                            .opacity(0.25)
                    )
            )
            .frame(width: 1)
    }
    
    // MARK: - Computed Properties
    
    private var contentAreaBackgroundColor: Color {
        Color.App.contentAreaBackground.color(for: colorScheme)
    }
    
    private var shadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.4)
            : Color.black.opacity(0.12)
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .frame(width: 900, height: 600)
}
