//
//  RestoreListView.swift
//  PocketPrefs
//
//  Restore backup list and management view
//

import SwiftUI

/// Main view for displaying and managing backup restoration.
struct RestoreListView: View {
    @ObservedObject var backupManager: BackupManager
    @Binding var selectedApp: AppConfig?

    @State private var selectedBackupApp: BackupAppInfo?
    @State private var searchText = ""
    @State private var isRefreshing = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            RestoreListHeader(
                backupManager: backupManager,

                searchText: $searchText,
                isRefreshing: $isRefreshing,
            )
            .padding(.bottom, 6)
            // No internal separator
            RestoreListContent(
                backupManager: backupManager,
                selectedBackupApp: $selectedBackupApp,
                searchText: searchText,
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Header view for the restore list, including backup selection, search, and refresh functionality.
struct RestoreListHeader: View {
    @ObservedObject var backupManager: BackupManager
    @Binding var searchText: String
    @Binding var isRefreshing: Bool
    @Environment(\.colorScheme) var colorScheme
    
    // Calculate all selected state for restore apps
    private var allRestoreAppsSelected: Bool {
        guard let backup = backupManager.selectedBackup else { return false }
        let filteredApps = backup.apps.filter {
            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
        }
        return !filteredApps.isEmpty && filteredApps.allSatisfy(\.isSelected)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Display the title for the restore backup view
            Text(NSLocalizedString("Restore_Backup_Title", comment: ""))
                .font(DesignConstants.Typography.title)
                .foregroundColor(Color.App.primary.color(for: colorScheme))
            
            // Backup selector with refresh button
            HStack(spacing: 12) {
                CustomBackupPicker(
                    backupManager: backupManager,
                )
                
                // Refresh button positioned after selector
                RefreshButton(
                    isRefreshing: $isRefreshing,
                    action: {
                        Task { @MainActor in
                            await refreshBackups()
                        }
                    },
                )
            }
            
            // Search bar - only show if backup selected
            if backupManager.selectedBackup != nil {
                SearchFieldView(searchText: $searchText)
                
                // Select all toggle and selection count
                HStack {
                    Toggle(isOn: Binding(
                        get: { allRestoreAppsSelected },
                        set: { newValue in
                            guard let backup = backupManager.selectedBackup else { return }
                            let filteredApps = backup.apps.filter {
                                searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
                            }
                            
                            for app in filteredApps {
                                if newValue != app.isSelected {
                                    backupManager.toggleRestoreSelection(for: app)
                                }
                            }
                        },
                    )) {
                        Text(NSLocalizedString("Select_All", comment: ""))
                            .font(DesignConstants.Typography.body)
                    }
                    .toggleStyle(CustomCheckboxToggleStyle())
                    
                    Spacer()
                    
                    // Selection status
                    if let backup = backupManager.selectedBackup {
                        let filteredCount = backup.apps
                            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
                            .count(where: { $0.isSelected })
                            
                        let totalFilteredCount = backup.apps
                            .count(where: { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) })
                            
                        Text(String(format: NSLocalizedString("Selected_Count", comment: ""), filteredCount, totalFilteredCount))
                            .font(DesignConstants.Typography.caption)
                            .foregroundColor(Color.App.secondary.color(for: colorScheme))
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 11)
        .background(
            Color.App.contentAreaBackground.color(for: colorScheme),
        )
    }
    
    @MainActor
    private func refreshBackups() async {
        isRefreshing = true
        
        // Add slight delay for visual feedback
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // Refresh backup list
        await backupManager.scanBackups()
        
        isRefreshing = false
    }
}

/// Enhanced search field component with styling and clear button.
struct SearchFieldView: View {
    @Binding var searchText: String
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
                .font(.system(size: 14))
            
            TextField(NSLocalizedString("Search_Placeholder", comment: ""), text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isFocused)
                .font(DesignConstants.Typography.body)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.App.secondary.color(for: colorScheme))
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                .fill(
                    (Color.App.tertiaryBackground.color(for: colorScheme)).opacity(0.7),
                ),
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                .stroke(
                    Color.App.lightSeparator.color(for: colorScheme).opacity(0.7),
                    lineWidth: 1.0,
                ),
        )

        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

/// A reusable refresh button component with an animated loading indicator.
struct RefreshButton: View {
    @Binding var isRefreshing: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Color.clear
                    .contentShape(RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius))
                
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.App.primary.color(for: colorScheme))
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(
                        isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default,
                        value: isRefreshing,
                    )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 32, height: 32)
        .background(
            Color.App.contentAreaBackground.color(for: colorScheme),
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius))
        .disabled(isRefreshing)
    }
}

/// Displays the content of the restore list, including filtered applications or empty states.
struct RestoreListContent: View {
    @ObservedObject var backupManager: BackupManager
    @Binding var selectedBackupApp: BackupAppInfo?
    let searchText: String
    @Environment(\.colorScheme) var colorScheme
    
    // Filter apps based on search text
    private var filteredApps: [BackupAppInfo] {
        guard let backup = backupManager.selectedBackup else { return [] }
        
        if searchText.isEmpty {
            return backup.apps
        } else {
            return backup.apps.filter { app in
                app.name.localizedCaseInsensitiveContains(searchText) ||
                    app.bundleId.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        if backupManager.selectedBackup != nil, !backupManager.availableBackups.isEmpty {
            if filteredApps.isEmpty, !searchText.isEmpty {
                // Empty search results
                SearchEmptyState(searchText: searchText)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // Use backup ID as part of ForEach to ensure proper updates
                        ForEach(filteredApps, id: \.id) { app in
                            RestoreAppItem(
                                app: app,
                                isSelected: selectedBackupApp?.id == app.id,
                                backupManager: backupManager,
                            ) {
                                withAnimation(DesignConstants.Animation.quick) {
                                    selectedBackupApp = app
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        } else {
            RestoreEmptyState()
        }
    }
}

/// Displays a message when no search results are found in the restore list.
struct SearchEmptyState: View {
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

/// Displays a message when no backups are found or selected.
struct RestoreEmptyState: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "archivebox")
                .font(.system(size: 48))
                .foregroundColor((Color.App.secondary.color(for: colorScheme)).opacity(0.5))
            Text(NSLocalizedString("Restore_Empty_State_No_Backups", comment: ""))
                .font(DesignConstants.Typography.headline)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
            Text(NSLocalizedString("Restore_Empty_State_Create_Backup_Prompt", comment: ""))
                .font(DesignConstants.Typography.body)
                .foregroundColor((Color.App.secondary.color(for: colorScheme)).opacity(0.8))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Represents a single application item in the restore list, displaying its icon, name, and selection status.
struct RestoreAppItem: View {
    let app: BackupAppInfo
    let isSelected: Bool
    @ObservedObject var backupManager: BackupManager
    let onTap: () -> Void
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 5) {
            // Checkbox
            Toggle("", isOn: Binding(
                get: { app.isSelected },
                set: { _ in backupManager.toggleRestoreSelection(for: app) },
            ))
            .toggleStyle(CustomCheckboxToggleStyle())
            
            // App Icon - Get icon from backupManager
            Group {
                let icon = backupManager.getIcon(for: app)
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // App Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(app.name)
                        .font(DesignConstants.Typography.headline)
                        .foregroundColor(Color.App.primary.color(for: colorScheme))
                    
                    if !app.isCurrentlyInstalled {
                        StatusBadge(
                            text: NSLocalizedString("Restore_App_Status_Not_Installed", comment: ""),
                            color: Color.App.warning.color(for: colorScheme),
                            style: .compact,
                        )
                    } else {
                        StatusBadge(
                            text: NSLocalizedString("Restore_App_Status_Installed", comment: ""),
                            color: Color.App.success.color(for: colorScheme),
                            style: .compact,
                        )
                    }
                }
                
                Text(String(format: NSLocalizedString("Restore_App_Config_Files_Count", comment: ""), app.configPaths.count))
                    .font(DesignConstants.Typography.caption)
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }
            
            Spacer()
            
            // Vertical bar indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
                .opacity(isHovered ? 0.6 : 0)
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
