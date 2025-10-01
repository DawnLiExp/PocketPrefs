//
//  AppListView.swift
//  PocketPrefs
//
//  Main view for displaying a list of applications with incremental backup support
//

import SwiftUI

/// Main view for displaying a list of applications.
struct AppListView: View {
    @ObservedObject var backupManager: BackupManager
    @Binding var selectedApp: AppConfig?
    let currentMode: MainView.AppMode
    @State private var searchText = ""
    @Environment(\.colorScheme) var colorScheme
    
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
            AppListHeader(
                searchText: $searchText,
                backupManager: backupManager,
            )
            
            if filteredApps.isEmpty, !searchText.isEmpty {
                BackupSearchEmptyState(searchText: searchText)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredApps) { app in
                            AppListItem(
                                app: app,
                                isSelected: selectedApp?.id == app.id,
                                backupManager: backupManager,
                                currentMode: currentMode,
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

/// Header view for the application list with search box, select all toggle, and incremental mode.
struct AppListHeader: View {
    @Binding var searchText: String
    @ObservedObject var backupManager: BackupManager
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isSearchFocused: Bool
    @State private var isRefreshing = false
    
    private var allInstalledSelected: Bool {
        let installedApps = backupManager.apps.filter(\.isInstalled)
        return !installedApps.isEmpty && installedApps.allSatisfy(\.isSelected)
    }
    
    private var hasAvailableBackups: Bool {
        !backupManager.availableBackups.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
                    .font(.system(size: 14))
                
                TextField(
                    NSLocalizedString("Search_Placeholder", comment: ""),
                    text: $searchText,
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
            .animation(.easeInOut(duration: 0.15), value: isSearchFocused)
            .padding(.bottom, 6)
            
            // Select all and incremental mode
            HStack(spacing: 16) {
                Toggle(isOn: Binding(
                    get: { allInstalledSelected },
                    set: { newValue in
                        if newValue {
                            backupManager.selectAll()
                        } else {
                            backupManager.deselectAll()
                        }
                    },
                )) {
                    Text(NSLocalizedString("Select_All", comment: ""))
                        .font(DesignConstants.Typography.body)
                }
                .toggleStyle(CustomCheckboxToggleStyle())
                
                IncrementalModeToggle(
                    backupManager: backupManager,
                    hasAvailableBackups: hasAvailableBackups,
                )
                
                Spacer()
                
                Text(String(
                    format: NSLocalizedString("Selected_Count", comment: ""),
                    backupManager.apps.count(where: { $0.isSelected }),
                    backupManager.apps.count,
                ))
                .font(DesignConstants.Typography.caption)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }
            .padding(.bottom, backupManager.isIncrementalMode && hasAvailableBackups ? 0 : 0)
            
            // Incremental base backup selector (shown when incremental mode is enabled)
            if backupManager.isIncrementalMode, hasAvailableBackups {
                IncrementalBaseSelector(
                    backupManager: backupManager,
                    isRefreshing: $isRefreshing,
                )
                .padding(.top, 0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 11)
        .background(
            Color.App.contentAreaBackground.color(for: colorScheme),
        )
    }
}

/// Incremental mode toggle with help popover
struct IncrementalModeToggle: View {
    @ObservedObject var backupManager: BackupManager
    let hasAvailableBackups: Bool
    @State private var showingHelp = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 6) {
            Toggle(isOn: Binding(
                get: { backupManager.isIncrementalMode },
                set: { newValue in
                    if hasAvailableBackups {
                        backupManager.isIncrementalMode = newValue
                    }
                },
            )) {
                Text(NSLocalizedString("Incremental_Mode", comment: ""))
                    .font(DesignConstants.Typography.body)
            }
            .toggleStyle(CustomCheckboxToggleStyle())
            .disabled(!hasAvailableBackups)
            
            Button(action: { showingHelp.toggle() }) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 14))
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }
            .buttonStyle(PlainButtonStyle())
            .popover(isPresented: $showingHelp, arrowEdge: .bottom) {
                IncrementalModeHelpPopover()
            }
        }
    }
}

/// Help popover content for incremental mode
struct IncrementalModeHelpPopover: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Text(NSLocalizedString("Incremental_Mode_Help_Description", comment: ""))
            .font(DesignConstants.Typography.body)
            .foregroundColor(Color.App.secondary.color(for: colorScheme))
            .multilineTextAlignment(.leading)
            .padding(12)
            .frame(width: 260, alignment: .leading)
    }
}

/// Incremental base backup selector with refresh button
struct IncrementalBaseSelector: View {
    @ObservedObject var backupManager: BackupManager
    @Binding var isRefreshing: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 8) {
            Text(NSLocalizedString("Select_Base_Backup_Label", comment: ""))
                .font(DesignConstants.Typography.body)
                .foregroundColor(Color.App.primary.color(for: colorScheme))
            
            Menu {
                ForEach(backupManager.availableBackups) { backup in
                    Button {
                        backupManager.selectIncrementalBase(backup)
                    } label: {
                        Text(backup.formattedName)
                    }
                }
            } label: {
                Text(backupManager.incrementalBaseBackup?.formattedName ?? "")
                    .font(DesignConstants.Typography.body)
                    .foregroundColor(Color.App.primary.color(for: colorScheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                            .fill(Color.App.tertiaryBackground.color(for: colorScheme).opacity(0.7)),
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                            .stroke(Color.App.lightSeparator.color(for: colorScheme).opacity(0.7), lineWidth: 1.0),
                    )
            }
            .menuStyle(.borderlessButton)
            .fixedSize(horizontal: false, vertical: true)
            
            Button(action: {
                Task { @MainActor in
                    await refreshBackups()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.App.primary.color(for: colorScheme))
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(
                        isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default,
                        value: isRefreshing,
                    )
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
    
    @MainActor
    private func refreshBackups() async {
        isRefreshing = true
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        await backupManager.scanBackups()
        
        isRefreshing = false
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

/// Represents a single application item in the list.
struct AppListItem: View {
    let app: AppConfig
    let isSelected: Bool
    let backupManager: BackupManager
    let currentMode: MainView.AppMode
    let onTap: () -> Void
    
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 5) {
            Toggle("", isOn: Binding(
                get: { app.isSelected },
                set: { _ in backupManager.toggleSelection(for: app) },
            ))
            .toggleStyle(CustomCheckboxToggleStyle())
            .disabled(currentMode == .backup ? !app.isInstalled : false)
            
            Group {
                let icon = backupManager.getIcon(for: app)
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(app.name)
                        .font(DesignConstants.Typography.headline)
                        .foregroundColor(app.isInstalled || currentMode == .restore ? Color.App.primary.color(for: colorScheme) : Color.App.secondary.color(for: colorScheme))
                    
                    if currentMode == .backup, !app.isInstalled {
                        StatusBadge(
                            text: NSLocalizedString("AppList_App_Status_Not_Installed", comment: ""),
                            color: Color.App.notInstalled.color(for: colorScheme),
                            style: .compact,
                        )
                    }
                }
                
                Text(String(format: NSLocalizedString("AppList_App_Config_Paths_Count", comment: ""), app.configPaths.count))
                    .font(DesignConstants.Typography.caption)
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }
            
            Spacer()
            
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
