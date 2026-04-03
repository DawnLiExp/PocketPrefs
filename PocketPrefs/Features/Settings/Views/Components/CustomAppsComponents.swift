//
//  CustomAppsComponents.swift
//  PocketPrefs
//
//  Custom apps management UI components
//

import SwiftUI

// MARK: - Custom App List Item

struct CustomAppListItem: View {
    let appId: String
    let isSelected: Bool
    let isDetailSelected: Bool
    let onToggleSelection: () -> Void
    let onSelectForDetail: () -> Void
    var manager: CustomAppManager
    @State private var isHovered = false
    @State private var iconRefreshTrigger = UUID()
    @Environment(\.colorScheme) var colorScheme
    
    private var app: AppConfig? {
        manager.customApps.first(where: { $0.id == appId })
    }
    
    var body: some View {
        if let app {
            HStack(spacing: 10) {
                Toggle(isOn: Binding(
                    get: { isSelected },
                    set: { _ in onToggleSelection() },
                )) {
                    EmptyView()
                }
                .toggleStyle(CustomCheckboxToggleStyle())
                
                Image(nsImage: IconService.shared.getIcon(for: app.bundleId, category: app.category))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .id(iconRefreshTrigger)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(app.name)
                            .font(DesignConstants.Typography.headline)
                            .foregroundColor(Color.App.primary.color(for: colorScheme))
                            .lineLimit(1)
                        
                        Spacer(minLength: 8)
                        
                        if !app.configPaths.isEmpty {
                            Text(String(localized: "Settings_Paths_Count", defaultValue: "\(app.configPaths.count) paths"))
                                .font(DesignConstants.Typography.caption)
                                .foregroundColor(Color.App.accent.color(for: colorScheme))
                        }
                    }
                    
                    Text(app.bundleId)
                        .font(DesignConstants.Typography.caption)
                        .foregroundColor(Color.App.secondary.color(for: colorScheme))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
                    .opacity(isDetailSelected ? 1 : (isHovered ? 0.5 : 0))
            }
            .padding(12)
            .cardEffect(isSelected: isDetailSelected)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelectForDetail)
            .onHover { hovering in
                isHovered = hovering
            }
            .task(id: app.bundleId) {
                for await loadedBundleId in IconService.shared.events {
                    if loadedBundleId == app.bundleId {
                        iconRefreshTrigger = UUID()
                        break
                    }
                }
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
                        Text("Settings_App_Information")
                            .font(DesignConstants.Typography.title)
                            .foregroundColor(Color.App.primary.color(for: colorScheme))
                        
                        // App Name
                        HStack {
                            Text("Settings_App_Name")
                                .font(DesignConstants.Typography.headline)
                                .frame(width: 100, alignment: .leading)
                            
                            if editingName {
                                HStack {
                                    TextField(text: $tempName) { EmptyView() }
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
                            Text("Settings_Bundle_ID")
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
    let appId: String
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
            Text("Settings_Add_New_App")
                .font(DesignConstants.Typography.title)
                .foregroundColor(Color.App.primary.color(for: colorScheme))
            
            Button(action: { showingAppPicker = true }) {
                HStack {
                    Image(systemName: "folder.badge.gearshape")
                    Text("Settings_Select_From_App")
                }
                .font(DesignConstants.Typography.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(isLoadingAppInfo)
            
            Text("Settings_Select_App_Hint")
                .font(DesignConstants.Typography.caption)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Settings_App_Name"))
                        .font(DesignConstants.Typography.headline)
                    TextField(String(localized: "Settings_App_Name_Placeholder"),
                              text: $appName)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isLoadingAppInfo)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Settings_Bundle_ID"))
                        .font(DesignConstants.Typography.headline)
                    TextField(String(localized: "Settings_Bundle_ID_Placeholder"),
                              text: $bundleId)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isLoadingAppInfo)
                    Text("Settings_Bundle_ID_Hint")
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
                Button(String(localized: "Common_Cancel"), action: onCancel)
                    .buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                    .disabled(isLoadingAppInfo)
                
                Button(String(localized: "Settings_Add_App"), action: onAdd)
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
                successMessage = String(localized: "AppInfo_Success_Message", defaultValue: "Loaded info from \(appURL.deletingPathExtension().lastPathComponent)")
                
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
            return String(localized: "Export_Selected")
        } else {
            return String(localized: "Export_All")
        }
    }

    private var exportTooltip: String {
        if !customAppManager.selectedAppIds.isEmpty {
            return String(localized: "Export_Selected_Tooltip_Count", defaultValue: "Export \(customAppManager.selectedAppIds.count) selected app configuration(s) to a file")
        } else {
            return String(localized: "Export_All_Tooltip")
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
                    "Import_Button",
                    systemImage: "square.and.arrow.down",
                )
                .font(DesignConstants.Typography.caption)
            }
            .buttonStyle(.bordered)
            .disabled(isImporting || isExporting)
            .help(Text("Import_Tooltip"))
            
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
                        Text(String(localized: "Selected_Count_Simple", defaultValue: "\(customAppManager.selectedAppIds.count) selected"))
                            .font(DesignConstants.Typography.caption)
                            .foregroundColor(Color.App.accent.color(for: colorScheme))
                        
                        Text(verbatim: "•")
                            .foregroundColor(Color.App.secondary.color(for: colorScheme))
                    }
                    
                    Text(String(localized: "Settings_Apps_Count", defaultValue: "\(customAppManager.customApps.count) apps"))
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
