//
//  CustomAppsView.swift
//  PocketPrefs
//
//  Custom Apps settings panel
//

import SwiftUI

struct CustomAppsView: View {
    var customAppManager: CustomAppManager
    var importExportManager: ImportExportManager
    
    @State private var searchDebouncer = SearchDebouncer()
    @State private var searchText = ""
    @State private var showingAddAppSheet = false
    @State private var newAppName = ""
    @State private var newAppBundleId = ""
    @State private var validationError = ""
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        DualColumnSettingsLayout(leftWidth: 280) {
            // Left Panel - Apps List
            VStack(spacing: 0) {
                // Toolbar
                SettingsToolbar(
                    searchText: $searchText,
                    selectedCount: customAppManager.selectedAppIds.count,
                    onAddApp: { showingAddAppSheet = true },
                    onDeleteSelected: deleteSelectedApps,
                    customAppManager: customAppManager
                )
                
                Divider()
                
                // Apps List
                if searchDebouncer.filteredApps.isEmpty {
                    EmptyAppsListView(searchActive: !searchText.isEmpty, searchText: searchText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(searchDebouncer.filteredApps) { app in
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
                                    manager: customAppManager
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
                    customAppManager: customAppManager
                )
            }
            .background(Color.App.controlBackground.color(for: colorScheme))
        } right: {
            // Right Panel - App Details
            if let selectedApp = customAppManager.selectedApp {
                CustomAppDetailView(
                    app: selectedApp,
                    manager: customAppManager
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyDetailView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
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
                manager: customAppManager
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
            bundleId: newAppBundleId
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
