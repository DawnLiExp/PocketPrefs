//
//  SettingsComponents.swift
//  PocketPrefs
//
//  Reusable UI components with reliable state updates
//

import SwiftUI

// MARK: - Settings Title Bar

struct SettingsTitleBar: View {
    let onClose: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            Text(NSLocalizedString("Settings_Title", comment: ""))
                .font(DesignConstants.Typography.title)
                .foregroundColor(Color.App.primary.color(for: colorScheme))
            
            Spacer()
            
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.App.secondaryBackground.color(for: colorScheme))
    }
}

// MARK: - Settings Toolbar

struct SettingsToolbar: View {
    @Binding var searchText: String
    let selectedCount: Int
    let onAddApp: () -> Void
    let onDeleteSelected: () -> Void
    let onRefresh: () -> Void
    let customAppManager: CustomAppManager
    @State private var showingRefreshHelp = false
    @State private var isRefreshing = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
                
                TextField(NSLocalizedString("Search_Placeholder", comment: "Search apps..."), text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.App.secondary.color(for: colorScheme))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.App.tertiaryBackground.color(for: colorScheme).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Action buttons
            HStack {
                Button(action: onAddApp) {
                    Label(NSLocalizedString("Settings_Add_App", comment: ""),
                          systemImage: "plus")
                        .font(DesignConstants.Typography.body)
                }
                .buttonStyle(.bordered)
                
                if selectedCount > 0 {
                    Button(action: onDeleteSelected) {
                        Label(String(format: NSLocalizedString("Settings_Delete_Selected", comment: ""),
                                     selectedCount),
                              systemImage: "trash")
                            .font(DesignConstants.Typography.body)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.App.error.color(for: colorScheme))
                }
                
                Spacer()
                
                // Refresh help button
                Button(action: { showingRefreshHelp.toggle() }) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 16))
                        .foregroundColor(Color.App.secondary.color(for: colorScheme))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingRefreshHelp, arrowEdge: .bottom) {
                    RefreshHelpPopover()
                }
                
                // Manual refresh button
                Button(action: {
                    Task {
                        isRefreshing = true
                        onRefresh()
                        try? await Task.sleep(for: .milliseconds(300))
                        isRefreshing = false
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.App.accent.color(for: colorScheme))
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(
                            isRefreshing ? .linear(duration: 0.6).repeatForever(autoreverses: false) : .default,
                            value: isRefreshing,
                        )
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)
                .help(NSLocalizedString("Settings_Refresh_Tooltip", comment: "Refresh app list"))
            }
            
            HStack {
                Toggle(isOn: Binding(
                    get: { !customAppManager.customApps.isEmpty && customAppManager.selectedAppIds.count == customAppManager.customApps.count },
                    set: { newValue in
                        if newValue {
                            Task {
                                await customAppManager.selectAll()
                            }
                        } else {
                            customAppManager.deselectAll()
                        }
                    },
                )) {
                    Text(NSLocalizedString("Select_All", comment: ""))
                        .font(DesignConstants.Typography.body)
                }
                .toggleStyle(.checkbox)
                
                Spacer()
                
                Text(String(format: NSLocalizedString("Selected_Count", comment: ""), customAppManager.selectedAppIds.count, customAppManager.customApps.count))
                    .font(DesignConstants.Typography.caption)
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }
        }
        .padding(12)
    }
}

// MARK: - Custom App List Item

struct CustomAppListItem: View {
    let app: AppConfig
    let isSelected: Bool
    let isDetailSelected: Bool
    let onToggleSelection: () -> Void
    let onSelectForDetail: () -> Void
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
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
        // Force refresh when app changes
        .id("\(app.id)-\(app.configPaths.count)")
    }
}

// MARK: - Custom App Detail View

struct CustomAppDetailView: View {
    let app: AppConfig
    @ObservedObject var manager: CustomAppManager
    @State private var editingName = false
    @State private var tempName = ""
    @Environment(\.colorScheme) var colorScheme
    
    // Always get fresh app data from manager
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
                    PathPickerViewWrapper(app: currentApp, manager: manager)
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
    let app: AppConfig
    @ObservedObject var manager: CustomAppManager
    
    var body: some View {
        PathPickerView(
            paths: Binding(
                get: { app.configPaths },
                set: { newPaths in
                    var updatedApp = app
                    updatedApp.configPaths = newPaths
                    manager.updateApp(updatedApp)
                },
            ),
            manager: manager,
        )
    }
}

// MARK: - Empty States

struct EmptyAppsListView: View {
    let searchActive: Bool
    let searchText: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: searchActive ? "magnifyingglass" : "plus.app")
                .font(.system(size: 48))
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
            
            Text(searchActive ?
                String(format: NSLocalizedString("Search_No_Results", comment: ""), searchText) :
                NSLocalizedString("Settings_No_Custom_Apps", comment: ""))
                .font(DesignConstants.Typography.headline)
                .foregroundColor(Color.App.primary.color(for: colorScheme))
                       
            Text(searchActive ?
                NSLocalizedString("Search_Try_Different_Keyword", comment: "") :
                NSLocalizedString("Settings_Add_First_App_Hint", comment: ""))
                .font(DesignConstants.Typography.caption)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 48))
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
            
            Text(NSLocalizedString("Settings_Select_App_To_Configure", comment: ""))
                .font(DesignConstants.Typography.headline)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    @StateObject private var appInfoReader = AppInfoReaderWrapper()
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
                    .buttonStyle(PrimaryButtonStyle())
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
                
                try? await Task.sleep(for: .seconds(3))
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

@MainActor
final class AppInfoReaderWrapper: ObservableObject {
    let reader = AppInfoReader()
}

// MARK: - Refresh Help Popover

struct RefreshHelpPopover: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("Settings_Refresh_Help_Title", comment: "When to Refresh"))
                .font(DesignConstants.Typography.headline)
                .foregroundColor(Color.App.primary.color(for: colorScheme))
            
            VStack(alignment: .leading, spacing: 8) {
                HelpItem(text: NSLocalizedString("Settings_Refresh_Help_Add", comment: "After adding new apps"))
                HelpItem(text: NSLocalizedString("Settings_Refresh_Help_Edit", comment: "After editing app configurations"))
                HelpItem(text: NSLocalizedString("Settings_Refresh_Help_Import", comment: "After importing configurations"))
                HelpItem(text: NSLocalizedString("Settings_Refresh_Help_Delete", comment: "After deleting apps"))
            }
            
            Divider()
                .padding(.vertical, 4)
            
            Text(NSLocalizedString("Settings_Refresh_Help_Footer", comment: "Click refresh to sync changes to main interface"))
                .font(DesignConstants.Typography.caption)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
        }
        .padding(16)
        .frame(width: 280)
        .background(Color.App.secondaryBackground.color(for: colorScheme))
    }
}

struct HelpItem: View {
    let text: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundColor(Color.App.accent.color(for: colorScheme))
                .padding(.top, 6)
            
            Text(text)
                .font(DesignConstants.Typography.body)
                .foregroundColor(Color.App.primary.color(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
