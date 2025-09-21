//
//  AppListView.swift
//  PocketPrefs
//
//  Main view for displaying a list of applications
//

import SwiftUI

/// Main view for displaying a list of applications.
struct AppListView: View {
    @ObservedObject var backupManager: BackupManager
    @Binding var selectedApp: AppConfig?
    let currentMode: MainView.AppMode
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            AppListHeader(backupManager: backupManager)
            
            // App List - no internal separator
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(backupManager.apps) { app in
                        AppListItem(
                            app: app,
                            isSelected: selectedApp?.id == app.id,
                            backupManager: backupManager,
                            currentMode: currentMode
                        ) {
                            withAnimation(DesignConstants.Animation.quick) {
                                selectedApp = app
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Header view for the application list, including a "Select All" toggle and selection count.
struct AppListHeader: View {
    @ObservedObject var backupManager: BackupManager
    @Environment(\.colorScheme) var colorScheme
    
    // Calculate initial state based on actual selection
    private var allInstalledSelected: Bool {
        let installedApps = backupManager.apps.filter { $0.isInstalled }
        return !installedApps.isEmpty && installedApps.allSatisfy { $0.isSelected }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Display the title for the applications list
            Text(NSLocalizedString("AppList_Title", comment: ""))
                .font(DesignConstants.Typography.title)
                .foregroundColor(Color.App.primary.color(for: colorScheme))
            
            HStack {
                Toggle(isOn: Binding(
                    get: { allInstalledSelected },
                    set: { newValue in
                        if newValue {
                            backupManager.selectAll()
                        } else {
                            backupManager.deselectAll()
                        }
                    }
                )) {
                    // Toggle to select or deselect all applications
                    Text(NSLocalizedString("AppList_Select_All", comment: ""))
                        .font(DesignConstants.Typography.body)
                }
                .toggleStyle(.checkbox)
                
                Spacer()
                
                Text(String(format: NSLocalizedString("AppList_Selected_Count", comment: ""), backupManager.apps.filter { $0.isSelected }.count, backupManager.apps.count))
                    .font(DesignConstants.Typography.caption)
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }
        }
        .padding(20)
        .background(
            (Color.App.tertiaryBackground.color(for: colorScheme)).opacity(0.3)
        )
    }
}

/// Represents a single application item in the list, displaying its icon, name, and selection status.
struct AppListItem: View {
    let app: AppConfig
    let isSelected: Bool
    let backupManager: BackupManager
    let currentMode: MainView.AppMode
    let onTap: () -> Void
    
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Toggle("", isOn: Binding(
                get: { app.isSelected },
                set: { _ in backupManager.toggleSelection(for: app) }
            ))
            .toggleStyle(.checkbox)
            .disabled(currentMode == .backup ? !app.isInstalled : false)
            
            // App Icon
            Group {
                let icon = backupManager.getIcon(for: app)
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.App.lightSeparator.color(for: colorScheme), lineWidth: 0.5)
                    )
            }
            
            // App Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(app.name)
                        .font(DesignConstants.Typography.headline)
                        .foregroundColor(app.isInstalled || currentMode == .restore ? (Color.App.primary.color(for: colorScheme)) : (Color.App.secondary.color(for: colorScheme)))
                    
                    if currentMode == .backup && !app.isInstalled {
                        StatusBadge(
                            text: NSLocalizedString("AppList_App_Status_Not_Installed", comment: ""),
                            color: Color.App.notInstalled.color(for: colorScheme),
                            style: .compact
                        )
                    }
                }
                
                Text(String(format: NSLocalizedString("AppList_App_Config_Paths_Count", comment: ""), app.configPaths.count))
                    .font(DesignConstants.Typography.caption)
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
                .opacity(isHovered ? 1 : 0)
        }
        .padding(12)
        .cardEffect(isSelected: isSelected)
        .onTapGesture(perform: onTap)
        .onHover { hovering in
            withAnimation(DesignConstants.Animation.quick) {
                isHovered = hovering
            }
        }
    }
}
