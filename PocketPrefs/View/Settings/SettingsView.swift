//
//  SettingsView.swift
//  PocketPrefs
//
//  Settings interface with immediate state synchronization
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var customAppManager = CustomAppManager()
    @StateObject private var importExportManager = ImportExportManager()
    @StateObject private var searchDebouncer = SearchDebouncer()
    @State private var selectedTab: SettingsTab = .customApps
    @State private var searchText = ""
    @State private var showingAddAppSheet = false
    @State private var newAppName = ""
    @State private var newAppBundleId = ""
    @State private var validationError = ""
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    enum SettingsTab: String, CaseIterable {
        case customApps
        case preferences
        
        var title: String {
            switch self {
            case .customApps:
                return NSLocalizedString("Settings_Tab_Custom_Apps", comment: "")
            case .preferences:
                return NSLocalizedString("Settings_Tab_Preferences", comment: "")
            }
        }
        
        var icon: String {
            switch self {
            case .customApps:
                return "app.badge.fill"
            case .preferences:
                return "slider.horizontal.3"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            SettingsTabBar(selectedTab: $selectedTab, onClose: { dismiss() })
            
            Divider()
            
            // Content
            Group {
                switch selectedTab {
                case .customApps:
                    CustomAppsContent(
                        customAppManager: customAppManager,
                        importExportManager: importExportManager,
                        filteredApps: searchDebouncer.filteredApps,
                        searchText: $searchText,
                        showingAddAppSheet: $showingAddAppSheet,
                        newAppName: $newAppName,
                        newAppBundleId: $newAppBundleId,
                        validationError: $validationError,
                        onRefresh: performManualRefresh,
                    )
                    
                case .preferences:
                    PreferencesView()
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 750, height: 500)
        .background(Color.App.background.color(for: colorScheme))
        .sheet(isPresented: $showingAddAppSheet) {
            AddAppSheet(
                appName: $newAppName,
                bundleId: $newAppBundleId,
                validationError: $validationError,
                onAdd: addNewApp,
                onCancel: {
                    showingAddAppSheet = false
                    clearNewAppFields()
                },
                manager: customAppManager,
            )
        }
        .onChange(of: searchText) { _, newValue in
            searchDebouncer.updateSearch(newValue, in: customAppManager.customApps)
        }
        .onChange(of: customAppManager.customApps) { _, newApps in
            searchDebouncer.updateApps(newApps, searchText: searchText)
        }
        .onAppear {
            searchDebouncer.updateApps(customAppManager.customApps, searchText: searchText)
        }
        .onDisappear {
            SettingsEventPublisher.shared.publishDidClose()
        }
    }
    
    private func performManualRefresh() {
        customAppManager.manualRefresh()
        searchDebouncer.updateApps(customAppManager.customApps, searchText: searchText)
    }
    
    private func addNewApp() {
        guard !newAppName.isEmpty, !newAppBundleId.isEmpty else {
            validationError = NSLocalizedString("Settings_Validation_Empty_Fields", comment: "")
            return
        }
        
        guard customAppManager.isValidBundleId(newAppBundleId) else {
            validationError = NSLocalizedString("Settings_Validation_Invalid_BundleId", comment: "")
            return
        }
        
        guard !customAppManager.userStore.bundleIdExists(newAppBundleId) else {
            validationError = NSLocalizedString("Settings_Validation_Duplicate_BundleId", comment: "")
            return
        }
        
        let newApp = customAppManager.createNewApp(
            name: newAppName,
            bundleId: newAppBundleId,
        )
        
        customAppManager.addApp(newApp)
        
        showingAddAppSheet = false
        clearNewAppFields()
    }
    
    private func clearNewAppFields() {
        newAppName = ""
        newAppBundleId = ""
        validationError = ""
    }
}

// MARK: - Search Debouncer

@MainActor
final class SearchDebouncer: ObservableObject {
    @Published private(set) var filteredApps: [AppConfig] = []
    
    private var searchTask: Task<Void, Never>?
    private let debounceDelay: Duration = .milliseconds(300)
    
    func updateSearch(_ searchText: String, in apps: [AppConfig]) {
        searchTask?.cancel()
        
        if searchText.isEmpty {
            filteredApps = apps
            return
        }
        
        searchTask = Task {
            try? await Task.sleep(for: debounceDelay)
            
            guard !Task.isCancelled else { return }
            
            let lowercased = searchText.lowercased()
            filteredApps = apps.filter { app in
                app.name.lowercased().contains(lowercased) ||
                    app.bundleId.lowercased().contains(lowercased)
            }
        }
    }
    
    func updateApps(_ apps: [AppConfig], searchText: String) {
        if searchText.isEmpty {
            filteredApps = apps
        } else {
            updateSearch(searchText, in: apps)
        }
    }
}

// MARK: - Settings Tab Bar

struct SettingsTabBar: View {
    @Binding var selectedTab: SettingsView.SettingsTab
    let onClose: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            Spacer()
            
            // Centered Tabs
            HStack(spacing: 24) {
                ForEach(SettingsView.SettingsTab.allCases, id: \.self) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: { selectedTab = tab },
                    )
                }
            }
            
            Spacer()
            
            // Close Button
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
        }
        .padding(.vertical, 10)
        .background(Color.App.secondaryBackground.color(for: colorScheme))
    }
}

struct TabButton: View {
    let tab: SettingsView.SettingsTab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: .medium))
                Text(tab.title)
                    .font(DesignConstants.Typography.headline)
            }
            .foregroundColor(
                isSelected
                    ? Color.App.accent.color(for: colorScheme)
                    : Color.App.secondary.color(for: colorScheme),
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isSelected
                            ? Color.App.accent.color(for: colorScheme).opacity(0.1)
                            : (isHovered ? Color.App.hoverBackground.color(for: colorScheme) : Color.clear),
                    ),
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignConstants.Animation.quick) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Custom Apps Content

struct CustomAppsContent: View {
    @ObservedObject var customAppManager: CustomAppManager
    @ObservedObject var importExportManager: ImportExportManager
    let filteredApps: [AppConfig]
    @Binding var searchText: String
    @Binding var showingAddAppSheet: Bool
    @Binding var newAppName: String
    @Binding var newAppBundleId: String
    @Binding var validationError: String
    let onRefresh: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Panel - Apps List
            VStack(spacing: 0) {
                // Toolbar
                SettingsToolbar(
                    searchText: $searchText,
                    selectedCount: customAppManager.selectedAppIds.count,
                    onAddApp: { showingAddAppSheet = true },
                    onDeleteSelected: deleteSelectedApps,
                    onRefresh: onRefresh,
                    customAppManager: customAppManager,
                )
                
                Divider()
                
                // Apps List
                if filteredApps.isEmpty {
                    EmptyAppsListView(searchActive: !searchText.isEmpty, searchText: searchText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredApps) { app in
                                CustomAppListItem(
                                    appId: app.id,
                                    isSelected: customAppManager.selectedAppIds.contains(app.id),
                                    isDetailSelected: customAppManager.selectedApp?.id == app.id,
                                    onToggleSelection: {
                                        customAppManager.toggleSelection(for: app.id)
                                    },
                                    onSelectForDetail: {
                                        customAppManager.selectedApp = app
                                    },
                                    manager: customAppManager,
                                )
                            }
                        }
                        .padding(12)
                    }
                }
                
                Divider()
                
                // Bottom toolbar
                ImportExportToolbar(
                    importExportManager: importExportManager,
                    customAppManager: customAppManager,
                    onImportComplete: onRefresh,
                )
            }
            .frame(width: 320)
            .background(Color.App.controlBackground.color(for: colorScheme))
            
            Divider()
            
            // Right Panel - App Details
            if let selectedApp = customAppManager.selectedApp {
                CustomAppDetailView(
                    app: selectedApp,
                    manager: customAppManager,
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.App.background.color(for: colorScheme))
            } else {
                EmptyDetailView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.App.background.color(for: colorScheme))
            }
        }
    }
    
    private func deleteSelectedApps() {
        guard !customAppManager.selectedAppIds.isEmpty else { return }
        
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Settings_Delete_Confirmation_Title", comment: "")
        alert.informativeText = String(
            format: NSLocalizedString("Settings_Delete_Confirmation_Message", comment: ""),
            customAppManager.selectedAppIds.count,
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Common_Delete", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Common_Cancel", comment: ""))
        
        if alert.runModal() == .alertFirstButtonReturn {
            customAppManager.removeSelectedApps()
        }
    }
}

// MARK: - Import/Export Toolbar

struct ImportExportToolbar: View {
    @ObservedObject var importExportManager: ImportExportManager
    @ObservedObject var customAppManager: CustomAppManager
    let onImportComplete: () -> Void
    @State private var isExporting = false
    @State private var isImporting = false
    @Environment(\.colorScheme) var colorScheme
    
    private var exportButtonLabel: String {
        if !customAppManager.selectedAppIds.isEmpty {
            return NSLocalizedString("Export_Selected", comment: "")
        } else {
            return NSLocalizedString("Export_All", comment: "")
        }
    }

    private var exportTooltip: String {
        if !customAppManager.selectedAppIds.isEmpty {
            return String(
                format: NSLocalizedString("Export_Selected_Tooltip_Count", comment: ""),
                customAppManager.selectedAppIds.count,
            )
        } else {
            return NSLocalizedString("Export_All_Tooltip", comment: "")
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: {
                isImporting = true
                Task {
                    await importExportManager.importCustomApps()
                    
                    // Immediate sync after import completes
                    onImportComplete()
                    
                    isImporting = false
                }
            }) {
                Label(
                    NSLocalizedString("Import_Button", comment: ""),
                    systemImage: "square.and.arrow.down",
                )
                .font(DesignConstants.Typography.caption)
            }
            .buttonStyle(.bordered)
            .disabled(isImporting || isExporting)
            .help(NSLocalizedString("Import_Tooltip", comment: ""))
            
            Button(action: {
                isExporting = true
                Task {
                    let idsToExport = customAppManager.selectedAppIds.isEmpty ? nil : customAppManager.selectedAppIds
                    await importExportManager.exportCustomApps(selectedIds: idsToExport)
                    isExporting = false
                }
            }) {
                Label(exportButtonLabel, systemImage: "square.and.arrow.up")
                    .font(DesignConstants.Typography.caption)
            }
            .buttonStyle(.bordered)
            .disabled(customAppManager.customApps.isEmpty || isImporting || isExporting)
            .help(exportTooltip)
            
            Spacer()
            
            if !customAppManager.customApps.isEmpty {
                HStack(spacing: 4) {
                    if !customAppManager.selectedAppIds.isEmpty {
                        Text(
                            String(
                                format: NSLocalizedString("Selected_Count_Simple", comment: ""),
                                customAppManager.selectedAppIds.count,
                            ),
                        )
                        .font(DesignConstants.Typography.caption)
                        .foregroundColor(Color.App.accent.color(for: colorScheme))
                        
                        Text("•")
                            .foregroundColor(Color.App.secondary.color(for: colorScheme))
                    }
                    
                    Text(
                        String(
                            format: NSLocalizedString("Settings_Apps_Count", comment: ""),
                            customAppManager.customApps.count,
                        ),
                    )
                    .font(DesignConstants.Typography.caption)
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.App.tertiaryBackground.color(for: colorScheme).opacity(0.3))
    }
}
