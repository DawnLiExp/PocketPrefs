//
//  AppListView.swift
//  PocketPrefs
//
//  Created by Me2 on 2025/9/18.
//

import SwiftUI

/// Main view for displaying a list of applications.
struct AppListView: View {
    @ObservedObject var backupManager: BackupManager
    @Binding var selectedApp: AppConfig?
    let currentMode: MainView.AppMode
    @State private var selectAll = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            AppListHeader(
                selectAll: $selectAll,
                backupManager: backupManager
            )
            
            Divider()
            
            // App List
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
                .padding(12)
            }
            .background(Color.App.background)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.App.background)
    }
}

/// Header view for the application list, including a "Select All" toggle and selection count.
struct AppListHeader: View {
    @Binding var selectAll: Bool
    @ObservedObject var backupManager: BackupManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Display the title for the applications list
            Text(NSLocalizedString("AppList_Title", comment: ""))
                .font(DesignConstants.Typography.title)
                .foregroundColor(.primary)
            
            HStack {
                Toggle(isOn: $selectAll) {
                    // Toggle to select or deselect all applications
                    Text(NSLocalizedString("AppList_Select_All", comment: ""))
                        .font(DesignConstants.Typography.body)
                }
                .toggleStyle(.checkbox)
                .onChange(of: selectAll) { _, newValue in
                    if newValue {
                        backupManager.selectAll()
                    } else {
                        backupManager.deselectAll()
                    }
                }
                
                Spacer()
                
                Text(String(format: NSLocalizedString("AppList_Selected_Count", comment: ""), backupManager.apps.filter { $0.isSelected }.count, backupManager.apps.count))
                    .font(DesignConstants.Typography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
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
                            .stroke(Color.App.separator.opacity(0.3), lineWidth: 0.5)
                    )
            }
            
            // App Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(app.name)
                        .font(DesignConstants.Typography.headline)
                        .foregroundColor(app.isInstalled || currentMode == .restore ? .primary : .secondary)
                    
                    if currentMode == .backup && !app.isInstalled {
                        StatusBadge(
                            text: NSLocalizedString("AppList_App_Status_Not_Installed", comment: ""),
                            color: .orange,
                            style: .compact
                        )
                    }
                }
                
                Text(String(format: NSLocalizedString("AppList_App_Config_Paths_Count", comment: ""), app.configPaths.count))
                    .font(DesignConstants.Typography.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
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
