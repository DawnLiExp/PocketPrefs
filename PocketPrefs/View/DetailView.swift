//
//  DetailView.swift
//  PocketPrefs
//
//  Created by Me2 on 2025/9/18.
//

import SwiftUI

// MARK: - DetailContainerView

/// A container view that manages the display of app details or placeholders based on the current mode and processing state.
struct DetailContainerView: View {
    let selectedApp: AppConfig?
    @ObservedObject var backupManager: BackupManager // Changed to @ObservedObject for reactivity
    let currentMode: MainView.AppMode
    @Binding var isProcessing: Bool
    @Binding var progress: Double
    @Binding var showingRestorePicker: Bool
    
    var body: some View {
        if isProcessing {
            ProgressView(progress: progress)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if currentMode == .backup {
            if let app = selectedApp {
                AppDetailView(
                    app: app,
                    backupManager: backupManager,
                    currentMode: currentMode,
                    isProcessing: $isProcessing,
                    progress: $progress,
                    showingRestorePicker: $showingRestorePicker
                )
            } else {
                BackupPlaceholderView(
                    backupManager: backupManager,
                    isProcessing: $isProcessing,
                    progress: $progress
                )
            }
        } else {
            RestorePlaceholderView(
                backupManager: backupManager,
                isProcessing: $isProcessing,
                progress: $progress
            )
        }
    }
}

// MARK: - AppDetailView

/// Displays the detailed view for a selected application in backup mode.
struct AppDetailView: View {
    let app: AppConfig
    @ObservedObject var backupManager: BackupManager // Changed to @ObservedObject
    let currentMode: MainView.AppMode
    @Binding var isProcessing: Bool
    @Binding var progress: Double
    @Binding var showingRestorePicker: Bool
    @State private var selectedPaths: Set<String> = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            AppDetailHeader(
                app: app,
                currentMode: currentMode,
                selectedPaths: $selectedPaths
            )
            
            Divider()
            
            // Config Paths List
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(app.configPaths, id: \.self) { path in
                        ConfigPathItem(
                            path: path,
                            isSelected: selectedPaths.contains(path)
                        ) {
                            togglePath(path)
                        }
                    }
                }
                .padding(16)
            }
            
            Spacer()
            
            // Action Button
            AppDetailActionBar(
                app: app,
                currentMode: currentMode,
                selectedPaths: selectedPaths,
                isProcessing: $isProcessing,
                progress: $progress,
                showingRestorePicker: $showingRestorePicker,
                backupManager: backupManager
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.App.background)
        .onAppear {
            selectedPaths = Set(app.configPaths)
        }
    }
    
    private func togglePath(_ path: String) {
        withAnimation(DesignConstants.Animation.quick) {
            if selectedPaths.contains(path) {
                selectedPaths.remove(path)
            } else {
                selectedPaths.insert(path)
            }
        }
    }
}

// MARK: - AppDetailHeader

/// Header for the application detail view, showing app name, bundle ID, and installation status.
struct AppDetailHeader: View {
    let app: AppConfig
    let currentMode: MainView.AppMode
    @Binding var selectedPaths: Set<String>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: currentMode == .backup ? "arrow.up.circle" : "arrow.down.circle")
                    .font(.system(size: 24))
                    .foregroundStyle(LinearGradient.appAccent)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name)
                        .font(DesignConstants.Typography.title)
                    
                    Text(app.bundleId)
                        .font(DesignConstants.Typography.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if currentMode == .backup {
                    if app.isInstalled {
                        StatusBadge(text: NSLocalizedString("Detail_App_Status_Installed", comment: ""), color: .green)

                    } else {
                        StatusBadge(text: NSLocalizedString("Detail_App_Status_Not_Installed", comment: ""), color: .orange)
                    }
                }
            }
            
            HStack {
                Toggle(isOn: Binding(
                    get: { selectedPaths.count == app.configPaths.count },
                    set: { newValue in
                        if newValue {
                            selectedPaths = Set(app.configPaths)
                        } else {
                            selectedPaths.removeAll()
                        }
                    }
                )) {
                    Text(NSLocalizedString("Detail_Select_All_Config_Files", comment: ""))
                        .font(DesignConstants.Typography.body)
                }
                .toggleStyle(.checkbox)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
    }
}

/// Action bar for the app detail view, containing backup or restore buttons.
struct AppDetailActionBar: View {
    let app: AppConfig
    let currentMode: MainView.AppMode
    let selectedPaths: Set<String>
    @Binding var isProcessing: Bool
    @Binding var progress: Double
    @Binding var showingRestorePicker: Bool
    @ObservedObject var backupManager: BackupManager // Changed to @ObservedObject
    
    var body: some View {
        HStack {
            Spacer()
            
            if currentMode == .backup {
                Button(action: performBackup) {
                    Label(NSLocalizedString("Detail_Action_Backup_Selected", comment: ""), systemImage: "arrow.up.circle.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selectedPaths.isEmpty || !app.isInstalled)
            } else {
                Button(action: { showingRestorePicker = true }) {
                    Label(NSLocalizedString("Detail_Action_Select_Backup_File_To_Restore", comment: ""), systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
    }
    
    private func performBackup() {
        withAnimation(DesignConstants.Animation.standard) {
            isProcessing = true
            progress = 0.0
        }
        
        Task { @MainActor in
            while progress < 0.9 {
                try? await Task.sleep(nanoseconds: 50_000_000)
                progress += 0.02
            }
            
            backupManager.performBackup()
            
            progress = 1.0
            try? await Task.sleep(nanoseconds: 500_000_000)
            isProcessing = false
            progress = 0.0
        }
    }
}

/// Displays a single configuration path item with a checkbox.
struct ConfigPathItem: View {
    let path: String
    let isSelected: Bool
    let onToggle: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.checkbox)
            
            Image(systemName: "folder")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Text(path)
                .font(DesignConstants.Typography.body)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
        }
        .padding(12)
        .cardEffect(isSelected: false)
        .onHover { hovering in
            withAnimation(DesignConstants.Animation.quick) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Placeholder Views

/// Placeholder view displayed when no application is selected in backup mode.
struct BackupPlaceholderView: View {
    @ObservedObject var backupManager: BackupManager
    @Binding var isProcessing: Bool
    @Binding var progress: Double
    
    // Check if there are any selected apps that are also installed
    private var hasValidSelection: Bool {
        !backupManager.apps.filter { $0.isSelected && $0.isInstalled }.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "arrowshape.turn.up.left.2.fill")
                    .font(.system(size: 108))
                    .foregroundStyle(LinearGradient.appAccent.opacity(0.6))
                
                Text(NSLocalizedString("Detail_Placeholder_Select_App", comment: ""))
                    .font(DesignConstants.Typography.headline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: performQuickBackup) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 20))
                        Text(NSLocalizedString("Detail_Placeholder_Quick_Backup_All_Selected", comment: ""))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!hasValidSelection)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.App.background)
    }
    
    private func performQuickBackup() {
        withAnimation(DesignConstants.Animation.standard) {
            isProcessing = true
            progress = 0.0
        }
        
        Task { @MainActor in
            while progress < 0.9 {
                try? await Task.sleep(nanoseconds: 50_000_000)
                progress += 0.02
            }
            
            backupManager.performBackup()
            
            progress = 1.0
            try? await Task.sleep(nanoseconds: 500_000_000)
            isProcessing = false
            progress = 0.0
        }
    }
}

/// Placeholder view displayed when no backup is selected in restore mode.
struct RestorePlaceholderView: View {
    @ObservedObject var backupManager: BackupManager
    @Binding var isProcessing: Bool
    @Binding var progress: Double
    
    var body: some View {
        VStack(spacing: 0) {
            if let backup = backupManager.selectedBackup {
                RestoreDetailContent(
                    backupManager: backupManager,
                    backup: backup,
                    isProcessing: $isProcessing,
                    progress: $progress
                )
            } else {
                RestoreEmptyDetail()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.App.background)
    }
}

/// Displays the detailed content of a selected backup in restore mode.
struct RestoreDetailContent: View {
    @ObservedObject var backupManager: BackupManager // Observing changes
    let backup: BackupInfo
    @Binding var isProcessing: Bool
    @Binding var progress: Double
    
    // Computed property to get selected apps count with proper reactivity
    private var selectedAppsCount: Int {
        backupManager.selectedBackup?.apps.filter { $0.isSelected }.count ?? 0
    }
    
    // Computed property for uninstalled selected apps
    private var uninstalledSelectedCount: Int {
        backupManager.selectedBackup?.apps.filter { !$0.isCurrentlyInstalled && $0.isSelected }.count ?? 0
    }
    
    // Computed property to check if any apps are selected
    private var hasSelectedApps: Bool {
        selectedAppsCount > 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Backup info header
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(LinearGradient.appAccent)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatBackupName(backup.name))
                            .font(DesignConstants.Typography.title)
                        
                        Text(String(format: NSLocalizedString("Detail_Restore_Backup_App_Count", comment: ""), backup.apps.count))
                            .font(DesignConstants.Typography.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Label(String(format: NSLocalizedString("Detail_Restore_Selected_Apps_Count", comment: ""), selectedAppsCount),
                          systemImage: "checkmark.circle.fill")
                        .font(DesignConstants.Typography.body)
                        .foregroundColor(selectedAppsCount > 0 ? .green : .secondary)
                    
                    Label(String(format: NSLocalizedString("Detail_Restore_Uninstalled_Apps_Count", comment: ""), uninstalledSelectedCount),
                          systemImage: "exclamationmark.triangle.fill")
                        .font(DesignConstants.Typography.body)
                        .foregroundColor(uninstalledSelectedCount > 0 ? .orange : .secondary)
                }
            }
            .padding(20)
            .background(.ultraThinMaterial)
            
            Divider()
            
            // Selected apps list
            if hasSelectedApps {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("Detail_Restore_Will_Restore_Apps", comment: ""))
                            .font(DesignConstants.Typography.headline)
                            .padding(.bottom, 8)
                        
                        // Use selectedBackup for real-time updates
                        ForEach(backupManager.selectedBackup?.apps.filter { $0.isSelected } ?? []) { app in
                            HStack {
                                Image(systemName: app.isCurrentlyInstalled ? "checkmark.circle" : "exclamationmark.circle")
                                    .foregroundColor(app.isCurrentlyInstalled ? .green : .orange)
                                
                                Text(app.name)
                                    .font(DesignConstants.Typography.body)
                                
                                if !app.isCurrentlyInstalled {
                                    Text(NSLocalizedString("Detail_Restore_App_Not_Installed_Badge", comment: ""))
                                        .font(DesignConstants.Typography.caption)
                                        .foregroundColor(.orange)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(16)
                }
            } else {
                // Empty state when no apps selected
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(NSLocalizedString("Detail_Restore_Empty_State_No_Apps_Selected", comment: ""))
                        .font(DesignConstants.Typography.headline)
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("Detail_Restore_Empty_State_Select_Apps_From_List", comment: ""))
                        .font(DesignConstants.Typography.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Spacer()
            
            // Action button with proper state binding
            HStack {
                Spacer()
                
                Button(action: performRestore) {
                    Label("执行恢复", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!hasSelectedApps) // Use computed property for proper reactivity
            }
            .padding(20)
            .background(.ultraThinMaterial)
        }
    }
    
    private func formatBackupName(_ name: String) -> String {
        name.replacingOccurrences(of: "Backup_", with: "")
    }
    
    private func performRestore() {
        withAnimation(DesignConstants.Animation.standard) {
            isProcessing = true
            progress = 0.0
        }
        
        Task { @MainActor in
            while progress < 0.9 {
                try? await Task.sleep(nanoseconds: 50_000_000)
                progress += 0.02
            }
            
            backupManager.performSelectiveRestore()
            
            progress = 1.0
            try? await Task.sleep(nanoseconds: 500_000_000)
            isProcessing = false
            progress = 0.0
        }
    }
}

struct RestoreEmptyDetail: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "archivebox")
                .font(.system(size: 48))
                .foregroundStyle(LinearGradient.appAccent.opacity(0.6))
            
            Text("请选择一个备份")
                .font(DesignConstants.Typography.headline)
                .foregroundColor(.secondary)
            
            Text("从左侧列表选择要恢复的备份")
                .font(DesignConstants.Typography.body)
                .foregroundColor(.secondary.opacity(0.8))
            
            Spacer()
        }
    }
}
