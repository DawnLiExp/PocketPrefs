//
//  SettingsView.swift
//  PocketPrefs
//
//  Settings interface with automatic state synchronization
//

import SwiftUI

struct SettingsView: View {
    @State private var customAppManager = CustomAppManager()
    @State private var importExportManager = ImportExportManager()
    @State private var backupManagementViewModel = BackupManagementViewModel()
    @State private var searchDebouncer = SearchDebouncer()
    @State private var selectedTab: SettingsTab = .preferences
    @State private var searchText = ""
    @State private var showingAddAppSheet = false
    @State private var newAppName = ""
    @State private var newAppBundleId = ""
    @State private var validationError = ""
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    enum SettingsTab: String, CaseIterable {
        case preferences
        case customApps
        case backups

        var title: String {
            switch self {
            case .customApps: return String(localized: "Settings_Tab_Custom_Apps")
            case .preferences: return String(localized: "Settings_Tab_Preferences")
            case .backups: return String(localized: "Settings_Tab_Backups")
            }
        }
        
        var icon: String {
            switch self {
            case .customApps: return "app.badge.fill"
            case .preferences: return "slider.horizontal.3"
            case .backups: return "externaldrive.badge.timemachine"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SettingsTabBar(selectedTab: $selectedTab, onClose: { dismiss() })
            
            Divider()
            
            Group {
                switch selectedTab {
                case .preferences:
                    PreferencesView()

                case .customApps:
                    CustomAppsContent(
                        customAppManager: customAppManager,
                        importExportManager: importExportManager,
                        filteredApps: searchDebouncer.filteredApps,
                        searchText: $searchText,
                        showingAddAppSheet: $showingAddAppSheet,
                        newAppName: $newAppName,
                        newAppBundleId: $newAppBundleId,
                        validationError: $validationError
                    )
                    
                case .backups:
                    BackupManagementView(viewModel: backupManagementViewModel)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 750, height: 500)
        .background(Color.App.contentAreaBackground.color(for: colorScheme))
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
    
    private func addNewApp() {
        guard !newAppName.isEmpty, !newAppBundleId.isEmpty else {
            validationError = String(localized: "Settings_Validation_Empty_Fields")
            return
        }
        
        guard customAppManager.isValidBundleId(newAppBundleId) else {
            validationError = String(localized: "Settings_Validation_Invalid_BundleId")
            return
        }
        
        guard !customAppManager.userStore.bundleIdExists(newAppBundleId) else {
            validationError = String(localized: "Settings_Validation_Duplicate_BundleId")
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

@Observable
@MainActor
final class SearchDebouncer {
    private(set) var filteredApps: [AppConfig] = []
    
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
            
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
        }
        .padding(.vertical, 10)
        .background(Color.App.contentAreaBackground.color(for: colorScheme))
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
    var customAppManager: CustomAppManager
    var importExportManager: ImportExportManager
    let filteredApps: [AppConfig]
    @Binding var searchText: String
    @Binding var showingAddAppSheet: Bool
    @Binding var newAppName: String
    @Binding var newAppBundleId: String
    @Binding var validationError: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Panel - Apps List
            VStack(spacing: 0) {
                SettingsToolbar(
                    searchText: $searchText,
                    selectedCount: customAppManager.selectedAppIds.count,
                    onAddApp: { showingAddAppSheet = true },
                    onDeleteSelected: deleteSelectedApps,
                    customAppManager: customAppManager,
                )
                
                Divider()
                
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
                
                ImportExportToolbar(
                    importExportManager: importExportManager,
                    customAppManager: customAppManager,
                )
            }
            .frame(width: 320)
            .background(Color.App.background.color(for: colorScheme))
            
            Divider()
            
            // Right Panel - App Details
            // contentAreaBackground 与窗口底色一致，形成干净的详情区域
            if let selectedApp = customAppManager.selectedApp {
                CustomAppDetailView(
                    app: selectedApp,
                    manager: customAppManager,
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.App.contentAreaBackground.color(for: colorScheme))
            } else {
                EmptyDetailView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.App.contentAreaBackground.color(for: colorScheme))
            }
        }
    }
    
    private func deleteSelectedApps() {
        guard !customAppManager.selectedAppIds.isEmpty else { return }
        
        let alert = NSAlert()
        alert.messageText = String(localized: "Settings_Delete_Confirmation_Title")
        alert.informativeText = String(localized: "Settings_Delete_Confirmation_Message", defaultValue: "Are you sure you want to delete \(customAppManager.selectedAppIds.count) selected app(s)?")
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Common_Delete"))
        alert.addButton(withTitle: String(localized: "Common_Cancel"))
        
        if alert.runModal() == .alertFirstButtonReturn {
            customAppManager.removeSelectedApps()
        }
    }
}
