//
//  CustomAppsComponents.swift
//  PocketPrefs
//
//  Custom apps management UI components
//

import SwiftUI

// MARK: - Custom App List Item

struct CustomAppListItem: View {
    let appId: UUID
    let isSelected: Bool
    let isDetailSelected: Bool
    let onToggleSelection: () -> Void
    let onSelectForDetail: () -> Void
    var manager: CustomAppManager
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    
    private var app: AppConfig? {
        manager.customApps.first(where: { $0.id == appId })
    }
    
    var body: some View {
        if let app {
            HStack(spacing: 12) {
                Toggle("", isOn: Binding(
                    get: { isSelected },
                    set: { _ in onToggleSelection() },
                ))
                .toggleStyle(.checkbox)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name)
                        .font(DesignConstants.Typography.headline)
                        .foregroundColor(Color.App.primary.color(for: colorScheme))
                    
                    Text(app.bundleId)
                        .font(DesignConstants.Typography.caption)
                        .foregroundColor(Color.App.secondary.color(for: colorScheme))
                    
                    if !app.configPaths.isEmpty {
                        Text(String(format: NSLocalizedString("Settings_Paths_Count", comment: ""),
                                    app.configPaths.count))
                            .font(DesignConstants.Typography.caption)
                            .foregroundColor(Color.App.accent.color(for: colorScheme))
                    }
                }
                
                Spacer()
                
                if isHovered || isDetailSelected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(Color.App.secondary.color(for: colorScheme))
                        .opacity(isDetailSelected ? 1 : 0.5)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isDetailSelected ?
                        Color.App.accent.color(for: colorScheme).opacity(0.1) :
                        Color.clear),
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isDetailSelected ?
                        Color.App.accent.color(for: colorScheme).opacity(0.3) :
                        Color.clear, lineWidth: 1),
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelectForDetail)
            .onHover { hovering in
                isHovered = hovering
            }
        }
    }
}

// MARK: - Custom App Detail View

struct CustomAppDetailView: View {
    let app: AppConfig
    var manager: CustomAppManager
    @State private var editingName = false
    @State private var tempName = ""
    @Environment(\.colorScheme) var colorScheme
    
    private var currentApp: AppConfig? {
        manager.customApps.first(where: { $0.id == app.id })
    }
    
    var body: some View {
        ScrollView {
            if let currentApp {
                VStack(alignment: .leading, spacing: 20) {
                    // App Info Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text(NSLocalizedString("Settings_App_Information", comment: ""))
                            .font(DesignConstants.Typography.title)
                            .foregroundColor(Color.App.primary.color(for: colorScheme))
                        
                        // App Name
                        HStack {
                            Text(NSLocalizedString("Settings_App_Name", comment: ""))
                                .font(DesignConstants.Typography.headline)
                                .frame(width: 100, alignment: .leading)
                            
                            if editingName {
                                HStack {
                                    TextField("", text: $tempName)
                                        .textFieldStyle(.roundedBorder)
                                    
                                    Button(action: { saveName(currentApp) }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color.App.success.color(for: colorScheme))
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button(action: cancelNameEdit) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Color.App.error.color(for: colorScheme))
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                Text(currentApp.name)
                                    .font(DesignConstants.Typography.body)
                                
                                Button(action: { startNameEdit(currentApp) }) {
                                    Image(systemName: "pencil.circle")
                                        .foregroundColor(Color.App.accent.color(for: colorScheme))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // Bundle ID
                        HStack {
                            Text(NSLocalizedString("Settings_Bundle_ID", comment: ""))
                                .font(DesignConstants.Typography.headline)
                                .frame(width: 100, alignment: .leading)
                            
                            Text(currentApp.bundleId)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(Color.App.secondary.color(for: colorScheme))
                        }
                    }
                    .padding()
                    .background(Color.App.tertiaryBackground.color(for: colorScheme).opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: DesignConstants.Layout.cornerRadius))
                    
                    // Configuration Paths Section
                    PathPickerViewWrapper(appId: currentApp.id, manager: manager)
                        .padding()
                        .background(Color.App.tertiaryBackground.color(for: colorScheme).opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.Layout.cornerRadius))
                }
                .padding(20)
            }
        }
        .id(app.id)
    }
    
    private func startNameEdit(_ currentApp: AppConfig) {
        tempName = currentApp.name
        editingName = true
    }
    
    private func saveName(_ currentApp: AppConfig) {
        guard !tempName.isEmpty else { return }
        var updatedApp = currentApp
        updatedApp.name = tempName
        manager.updateApp(updatedApp)
        editingName = false
    }
    
    private func cancelNameEdit() {
        editingName = false
        tempName = ""
    }
}

// MARK: - Path Picker Wrapper

struct PathPickerViewWrapper: View {
    let appId: UUID
    var manager: CustomAppManager
    
    private var currentApp: AppConfig? {
        manager.customApps.first(where: { $0.id == appId })
    }
    
    var body: some View {
        if currentApp != nil {
            PathPickerView(
                paths: Binding(
                    get: {
                        manager.customApps.first(where: { $0.id == appId })?.configPaths ?? []
                    },
                    set: { newPaths in
                        guard var updatedApp = manager.customApps.first(where: { $0.id == appId }) else { return }
                        updatedApp.configPaths = newPaths
                        manager.updateApp(updatedApp)
                    },
                ),
                manager: manager,
            )
        }
    }
}

// MARK: - Add App Sheet

struct AddAppSheet: View {
    @Binding var appName: String
    @Binding var bundleId: String
    @Binding var validationError: String
    let onAdd: () -> Void
    let onCancel: () -> Void
    let manager: CustomAppManager
    
    @State private var showingAppPicker = false
    @State private var isLoadingAppInfo = false
    @State private var successMessage = ""
    @State private var appInfoReader = AppInfoReaderWrapper()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 24) {
            Text(NSLocalizedString("Settings_Add_New_App", comment: ""))
                .font(DesignConstants.Typography.title)
                .foregroundColor(Color.App.primary.color(for: colorScheme))
            
            // Auto-fill button
            Button(action: { showingAppPicker = true }) {
                HStack {
                    Image(systemName: "folder.badge.gearshape")
                    Text(NSLocalizedString("Settings_Select_From_App", comment: ""))
                }
                .font(DesignConstants.Typography.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(isLoadingAppInfo)
            
            Text(NSLocalizedString("Settings_Select_App_Hint", comment: ""))
                .font(DesignConstants.Typography.caption)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("Settings_App_Name", comment: ""))
                        .font(DesignConstants.Typography.headline)
                    TextField(NSLocalizedString("Settings_App_Name_Placeholder", comment: ""),
                              text: $appName)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isLoadingAppInfo)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("Settings_Bundle_ID", comment: ""))
                        .font(DesignConstants.Typography.headline)
                    TextField(NSLocalizedString("Settings_Bundle_ID_Placeholder", comment: ""),
                              text: $bundleId)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isLoadingAppInfo)
                    Text(NSLocalizedString("Settings_Bundle_ID_Hint", comment: ""))
                        .font(DesignConstants.Typography.caption)
                        .foregroundColor(Color.App.secondary.color(for: colorScheme))
                }
                
                if isLoadingAppInfo {
                    HStack {
                        SwiftUI.ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading application info...")
                            .font(DesignConstants.Typography.caption)
                            .foregroundColor(Color.App.secondary.color(for: colorScheme))
                    }
                }
                
                if !successMessage.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color.App.success.color(for: colorScheme))
                        Text(successMessage)
                            .font(DesignConstants.Typography.caption)
                            .foregroundColor(Color.App.success.color(for: colorScheme))
                    }
                }
                
                if !validationError.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color.App.error.color(for: colorScheme))
                        Text(validationError)
                            .font(DesignConstants.Typography.caption)
                            .foregroundColor(Color.App.error.color(for: colorScheme))
                    }
                }
            }
            
            HStack(spacing: 12) {
                Button(NSLocalizedString("Common_Cancel", comment: ""), action: onCancel)
                    .buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                    .disabled(isLoadingAppInfo)
                
                Button(NSLocalizedString("Settings_Add_App", comment: ""), action: onAdd)
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(appName.isEmpty || bundleId.isEmpty || isLoadingAppInfo)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(30)
        .frame(width: 450)
        .background(Color.App.secondaryBackground.color(for: colorScheme))
        .fileImporter(
            isPresented: $showingAppPicker,
            allowedContentTypes: [.application],
            allowsMultipleSelection: false,
        ) { result in
            Task {
                await handleAppSelection(result)
            }
        }
    }
    
    @MainActor
    private func handleAppSelection(_ result: Result<[URL], Error>) async {
        successMessage = ""
        validationError = ""
        
        switch result {
        case .success(let urls):
            guard let appURL = urls.first else { return }
            
            isLoadingAppInfo = true
            
            do {
                let appInfo = try await appInfoReader.reader.readAppInfo(from: appURL)
                
                appName = appInfo.name
                bundleId = appInfo.bundleId
                successMessage = String(
                    format: NSLocalizedString("AppInfo_Success_Message", comment: ""),
                    appURL.deletingPathExtension().lastPathComponent,
                )
                
                try? await Task.sleep(for: .seconds(1))
                successMessage = ""
                
            } catch {
                validationError = error.localizedDescription
            }
            
            isLoadingAppInfo = false
            
        case .failure(let error):
            validationError = error.localizedDescription
        }
    }
}

// MARK: - AppInfoReader Wrapper

@Observable
@MainActor
final class AppInfoReaderWrapper {
    let reader = AppInfoReader()
}

// MARK: - Import/Export Toolbar

struct ImportExportToolbar: View {
    var importExportManager: ImportExportManager
    var customAppManager: CustomAppManager
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
