//
//  SettingsView.swift
//  PocketPrefs
//
//  Main settings interface for managing custom applications
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var customAppManager = CustomAppManager()
    @StateObject private var importExportManager = ImportExportManager()
    @State private var searchText = ""
    @State private var showingAddAppSheet = false
    @State private var newAppName = ""
    @State private var newAppBundleId = ""
    @State private var validationError = ""
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var filteredApps: [AppConfig] {
        if searchText.isEmpty {
            return customAppManager.customApps
        }
        return customAppManager.customApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.bundleId.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Title Bar
            SettingsTitleBar(onClose: { dismiss() })
            
            Divider()
            
            // Main Content
            HStack(spacing: 0) {
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
                    if filteredApps.isEmpty {
                        EmptyAppsListView(searchActive: !searchText.isEmpty, searchText: searchText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredApps) { app in
                                    CustomAppListItem(
                                        app: app,
                                        isSelected: customAppManager.selectedAppIds.contains(app.id),
                                        isDetailSelected: customAppManager.selectedApp?.id == app.id,
                                        onToggleSelection: {
                                            customAppManager.toggleSelection(for: app.id)
                                        },
                                        onSelectForDetail: {
                                            customAppManager.selectedApp = app
                                        }
                                    )
                                }
                            }
                            .padding(12)
                        }
                    }
                    
                    Divider()
                    
                    // Bottom toolbar with Import/Export buttons
                    ImportExportToolbar(
                        importExportManager: importExportManager,
                        customAppManager: customAppManager
                    )
                }
                .frame(width: 320)
                .background(Color.App.controlBackground.color(for: colorScheme))
                
                Divider()
                
                // Right Panel - App Details
                if let selectedApp = customAppManager.selectedApp {
                    CustomAppDetailView(
                        app: selectedApp,
                        manager: customAppManager
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
                manager: customAppManager
            )
        }
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
            bundleId: newAppBundleId
        )
        
        customAppManager.addApp(newApp)
        customAppManager.selectedApp = newApp
        
        showingAddAppSheet = false
        clearNewAppFields()
    }
    
    private func clearNewAppFields() {
        newAppName = ""
        newAppBundleId = ""
        validationError = ""
    }
    
    private func deleteSelectedApps() {
        guard !customAppManager.selectedAppIds.isEmpty else { return }
        
        // Show confirmation alert
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Settings_Delete_Confirmation_Title", comment: "")
        alert.informativeText = String(format: NSLocalizedString("Settings_Delete_Confirmation_Message", comment: ""),
                                       customAppManager.selectedAppIds.count)
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
    let customAppManager: CustomAppManager
    @State private var isExporting = false
    @State private var isImporting = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 8) {
            // Import button
            Button(action: {
                isImporting = true
                Task {
                    await importExportManager.importCustomApps()
                    isImporting = false
                }
            }) {
                Label(NSLocalizedString("Import_Button", comment: ""),
                      systemImage: "square.and.arrow.down")
                    .font(DesignConstants.Typography.caption)
            }
            .buttonStyle(.bordered)
            .disabled(isImporting || isExporting)
            .help(NSLocalizedString("Import_Tooltip", comment: ""))
            
            // Export button
            Button(action: {
                isExporting = true
                Task {
                    await importExportManager.exportCustomApps()
                    isExporting = false
                }
            }) {
                Label(NSLocalizedString("Export_Button", comment: ""),
                      systemImage: "square.and.arrow.up")
                    .font(DesignConstants.Typography.caption)
            }
            .buttonStyle(.bordered)
            .disabled(customAppManager.customApps.isEmpty || isImporting || isExporting)
            .help(NSLocalizedString("Export_Tooltip", comment: ""))
            
            Spacer()
            
            // Apps count indicator
            if !customAppManager.customApps.isEmpty {
                Text(String(format: NSLocalizedString("Settings_Apps_Count", comment: ""),
                            customAppManager.customApps.count))
                    .font(DesignConstants.Typography.caption)
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.App.tertiaryBackground.color(for: colorScheme).opacity(0.3))
    }
}
