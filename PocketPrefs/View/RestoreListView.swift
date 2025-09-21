//
//  RestoreListView.swift
//  PocketPrefs
//
//  Created by Me2 on 2025/9/18.
//

import SwiftUI

/// Main view for displaying and managing backup restoration.
struct RestoreListView: View {
    @ObservedObject var backupManager: BackupManager
    @Binding var selectedApp: AppConfig?
    @State private var showingFilePicker = false
    @State private var selectedBackupApp: BackupAppInfo?
    @State private var searchText = ""
    @State private var isRefreshing = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            RestoreListHeader(
                backupManager: backupManager,
                showingFilePicker: $showingFilePicker,
                searchText: $searchText,
                isRefreshing: $isRefreshing
            )
            
            // No internal separator
            RestoreListContent(
                backupManager: backupManager,
                selectedBackupApp: $selectedBackupApp,
                searchText: searchText
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFilePicker(result: result)
        }
    }
    
    private func handleFilePicker(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                var customBackup = BackupInfo(
                    path: url.path,
                    name: url.lastPathComponent,
                    date: Date()
                )
                customBackup.apps = backupManager.scanAppsInBackup(at: url.path)
                
                if !customBackup.apps.isEmpty {
                    backupManager.availableBackups.insert(customBackup, at: 0)
                    backupManager.selectBackup(customBackup)
                }
            }
        case .failure(let error):
            print("Failed to select backup: \(error)")
        }
    }
}

/// Header view for the restore list, including backup selection, search, and refresh functionality.
struct RestoreListHeader: View {
    @ObservedObject var backupManager: BackupManager
    @Binding var showingFilePicker: Bool
    @Binding var searchText: String
    @Binding var isRefreshing: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Display the title for the restore backup view
            Text(NSLocalizedString("Restore_Backup_Title", comment: ""))
                .font(DesignConstants.Typography.title)
                .foregroundColor((Color.App.primary.color(for: colorScheme)))
            
            // Backup selector with refresh button
            HStack(spacing: 12) {
                BackupSelectorView(
                    backupManager: backupManager,
                    showingFilePicker: $showingFilePicker
                )
                
                // Refresh button positioned after selector
                RefreshButton(
                    isRefreshing: $isRefreshing,
                    action: {
                        Task { @MainActor in
                            await refreshBackups()
                        }
                    }
                )
            }
            
            // Search bar - only show if backup selected
            if backupManager.selectedBackup != nil {
                SearchFieldView(searchText: $searchText)
            }
            
            // Selection status
            if let backup = backupManager.selectedBackup {
                let filteredCount = backup.apps
                    .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
                    .filter { $0.isSelected }
                    .count
                let totalFilteredCount = backup.apps
                    .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
                    .count
                
                Text(String(format: NSLocalizedString("Restore_Apps_Selected_Count", comment: ""), filteredCount, totalFilteredCount))
                    .font(DesignConstants.Typography.caption)
                    .foregroundColor((Color.App.secondary.color(for: colorScheme)))
            }
        }
        .padding(20)
        .background(
            (Color.App.tertiaryBackground.color(for: colorScheme)).opacity(0.3)
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
                .foregroundColor((Color.App.secondary.color(for: colorScheme)))
                .font(.system(size: 14))
            
            TextField(NSLocalizedString("Search apps...", comment: ""), text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isFocused)
                .font(DesignConstants.Typography.body)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor((Color.App.secondary.color(for: colorScheme)))
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
                    isFocused ? (Color.App.accent.color(for: colorScheme)).opacity(0.4) : (Color.App.lightSeparator.color(for: colorScheme)),
                    lineWidth: isFocused ? 1.5 : 1.0
                )
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
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor((Color.App.primary.color(for: colorScheme)))
                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                .animation(
                    isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default,
                    value: isRefreshing
                )
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 32, height: 32)
        .background(
            (Color.App.tertiaryBackground.color(for: colorScheme)).opacity(0.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                .stroke((Color.App.lightSeparator.color(for: colorScheme)), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius))
        .disabled(isRefreshing)
    }
}

/// A view for selecting a backup from available options or browsing for a new one.
struct BackupSelectorView: View {
    @ObservedObject var backupManager: BackupManager
    @Binding var showingFilePicker: Bool
    @Environment(\.colorScheme) var colorScheme
    
    // Custom wrapper for picker selection binding
    private var pickerBinding: Binding<BackupInfo?> {
        Binding(
            get: { backupManager.selectedBackup },
            set: { newValue in
                if let backup = newValue {
                    backupManager.selectBackup(backup)
                } else {
                    // User selected "browse" option
                    showingFilePicker = true
                }
            }
        )
    }
    
    var body: some View {
        Picker(NSLocalizedString("Select Backup:", comment: ""), selection: pickerBinding) {
            ForEach(backupManager.availableBackups) { backup in
                Text(formatBackupName(backup.name))
                    .tag(backup as BackupInfo?)
            }
            
            Divider()
            
            Text(NSLocalizedString("Select from other location...", comment: ""))
                .tag(nil as BackupInfo?)
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity)
    }
    
    private func formatBackupName(_ name: String) -> String {
        name.replacingOccurrences(of: "Backup_", with: "")
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
        if backupManager.selectedBackup != nil {
            if filteredApps.isEmpty && !searchText.isEmpty {
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
                                backupManager: backupManager
                            ) {
                                withAnimation(DesignConstants.Animation.quick) {
                                    selectedBackupApp = app
                                }
                            }
                        }
                    }
                    .padding(16)
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
            Text(String(format: NSLocalizedString("Restore_Search_No_Results", comment: ""), searchText))
                .font(DesignConstants.Typography.headline)
                .foregroundColor((Color.App.secondary.color(for: colorScheme)))
            Text(NSLocalizedString("Restore_Search_Try_Different_Keyword", comment: ""))
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
                .foregroundColor((Color.App.secondary.color(for: colorScheme)))
            Text(NSLocalizedString("Restore_Empty_State_Select_Location_Or_Create_Backup", comment: ""))
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
        HStack(spacing: 12) {
            // Checkbox
            Toggle("", isOn: Binding(
                get: { app.isSelected },
                set: { _ in backupManager.toggleRestoreSelection(for: app) }
            ))
            .toggleStyle(.checkbox)
            
            // App Icon - Get icon from backupManager
            Group {
                let icon = backupManager.getIcon(for: app)
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke((Color.App.lightSeparator.color(for: colorScheme)), lineWidth: 0.5)
                    )
            }
            
            // App Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(app.name)
                        .font(DesignConstants.Typography.headline)
                        .foregroundColor((Color.App.primary.color(for: colorScheme)))
                    
                    if !app.isCurrentlyInstalled {
                        StatusBadge(
                            text: NSLocalizedString("Restore_App_Status_Not_Installed", comment: ""),
                            color: (Color.App.warning.color(for: colorScheme)),
                            style: .compact
                        )
                    } else {
                        StatusBadge(
                            text: NSLocalizedString("Restore_App_Status_Installed", comment: ""),
                            color: (Color.App.success.color(for: colorScheme)),
                            style: .compact
                        )
                    }
                }
                
                Text(String(format: NSLocalizedString("Restore_App_Config_Files_Count", comment: ""), app.configPaths.count))
                    .font(DesignConstants.Typography.caption)
                    .foregroundColor((Color.App.secondary.color(for: colorScheme)))
            }
            
            Spacer()
            
            // Vertical bar indicator
            Text("│")
                .font(.system(size: 14))
                .foregroundColor((Color.App.secondary.color(for: colorScheme)))
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
