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
    @State private var searchText = ""
    @Environment(\.colorScheme) var colorScheme
    
    // Filter apps based on search text
    private var filteredApps: [AppConfig] {
        if searchText.isEmpty {
            return backupManager.apps
        }
        return backupManager.apps.filter { app in
            app.name.localizedCaseInsensitiveContains(searchText) ||
                app.bundleId.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search
            AppListHeader(
                searchText: $searchText,
                backupManager: backupManager
            )
            
            // Content area
            if filteredApps.isEmpty && !searchText.isEmpty {
                // Empty search results
                BackupSearchEmptyState(searchText: searchText)
            } else {
                // App List - no internal separator
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredApps) { app in
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Header view for the application list with search box and select all toggle.
struct AppListHeader: View {
    @Binding var searchText: String
    @ObservedObject var backupManager: BackupManager
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isSearchFocused: Bool
    
    // Calculate initial state based on actual selection
    private var allInstalledSelected: Bool {
        let installedApps = backupManager.apps.filter { $0.isInstalled }
        return !installedApps.isEmpty && installedApps.allSatisfy { $0.isSelected }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
                    .font(.system(size: 14))
                
                TextField(
                    NSLocalizedString("Search_Placeholder", comment: "Search apps..."),
                    text: $searchText
                )
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isSearchFocused)
                .font(DesignConstants.Typography.body)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.App.secondary.color(for: colorScheme))
                            .font(.system(size: 14))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                    .fill(
                        (Color.App.tertiaryBackground.color(for: colorScheme)).opacity(0.5)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                    .stroke(
                        Color.App.lightSeparator.color(for: colorScheme),
                        lineWidth: 1.0
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isSearchFocused)
            
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
                    Text(NSLocalizedString("Select_All", comment: ""))
                        .font(DesignConstants.Typography.body)
                }
                .toggleStyle(.checkbox)
                
                Spacer()
                
                Text(String(format: NSLocalizedString("Selected_Count", comment: ""), backupManager.apps.filter { $0.isSelected }.count, backupManager.apps.count))
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

/// Displays a message when no search results are found in the backup list.
struct BackupSearchEmptyState: View {
    let searchText: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor((Color.App.secondary.color(for: colorScheme)).opacity(0.5))
            Text(String(format: NSLocalizedString("Search_No_Results", comment: ""), searchText))
                .font(DesignConstants.Typography.headline)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
            Text(NSLocalizedString("Search_Try_Different_Keyword", comment: ""))
                .font(DesignConstants.Typography.body)
                .foregroundColor((Color.App.secondary.color(for: colorScheme)).opacity(0.8))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        .foregroundColor(app.isInstalled || currentMode == .restore ? Color.App.primary.color(for: colorScheme) : Color.App.secondary.color(for: colorScheme))
                    
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
