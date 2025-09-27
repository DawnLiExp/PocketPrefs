//
//  DetailView.swift
//  PocketPrefs
//
//  App detail and backup/restore management views
//

import AppKit
import SwiftUI

// MARK: - DetailContainerView

struct DetailContainerView: View {
    let selectedApp: AppConfig?
    @ObservedObject var backupManager: BackupManager
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

struct AppDetailView: View {
    let app: AppConfig
    @ObservedObject var backupManager: BackupManager
    let currentMode: MainView.AppMode
    @Binding var isProcessing: Bool
    @Binding var progress: Double
    @Binding var showingRestorePicker: Bool
    @Environment(\.colorScheme) var colorScheme
    
    private var hasValidSelection: Bool {
        !backupManager.apps.filter { $0.isSelected && $0.isInstalled }.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            AppDetailHeader(
                app: app,
                currentMode: currentMode
            )
            
            // Config Paths List
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(app.configPaths, id: \.self) { path in
                        ConfigPathItem(path: path)
                    }
                }
                .padding(16)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                
                Button(action: performBackup) {
                    Label(
                        NSLocalizedString("Detail_Action_Backup_Selected", comment: ""),
                        systemImage: "arrow.up.circle.fill"
                    )
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!hasValidSelection)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func performBackup() {
        withAnimation(DesignConstants.Animation.standard) {
            isProcessing = true
            progress = 0.0
        }
        
        Task { @MainActor in
            // Progress monitoring
            while progress < 0.98 {
                try? await Task.sleep(for: .milliseconds(30))
                progress += 0.0294
            }
            
            backupManager.performBackup()
            
            progress = 1.0
            try? await Task.sleep(for: .seconds(0.5))
            
            isProcessing = false
            progress = 0.0
        }
    }
}

// MARK: - AppDetailHeader

struct AppDetailHeader: View {
    let app: AppConfig
    let currentMode: MainView.AppMode
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: currentMode == .backup ? "arrow.up.circle" : "arrow.down.circle")
                    .font(.system(size: 24))
                    .foregroundColor(Color.App.accent.color(for: colorScheme))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name)
                        .font(DesignConstants.Typography.title)
                    
                    Text(app.bundleId)
                        .font(DesignConstants.Typography.caption)
                        .foregroundColor(Color.App.secondary.color(for: colorScheme))
                }
                
                Spacer()
                
                if currentMode == .backup {
                    if app.isInstalled {
                        StatusBadge(
                            text: NSLocalizedString("Detail_App_Status_Installed", comment: ""),
                            color: Color.App.success.color(for: colorScheme)
                        )
                    } else {
                        StatusBadge(
                            text: NSLocalizedString("Detail_App_Status_Not_Installed", comment: ""),
                            color: Color.App.warning.color(for: colorScheme)
                        )
                    }
                }
            }
            
            Text(String(format: NSLocalizedString("AppList_App_Config_Paths_Count", comment: ""), app.configPaths.count))
                .font(DesignConstants.Typography.body)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
        }
        .padding(20)
        .background(Color.App.contentAreaBackground.color(for: colorScheme))
    }
}

// MARK: - ConfigPathItem

struct ConfigPathItem: View {
    let path: String
    @State private var isHovered = false
    @State private var fileSize: String = "-"
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            Image(systemName: "folder")
                .font(.system(size: 14))
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(path)
                    .font(DesignConstants.Typography.body)
                    .foregroundColor(Color.App.primary.color(for: colorScheme))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Text(fileSize)
                    .font(DesignConstants.Typography.caption)
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }
            
            Spacer()
            
            Button(action: showInFinder) {
                Image(systemName: "magnifyingglass.circle")
                    .font(.system(size: 16))
                    .foregroundColor(
                        isHovered
                            ? Color.App.primary.color(for: colorScheme)
                            : Color.App.secondary.color(for: colorScheme)
                    )
            }
            .buttonStyle(.plain)
            .help("Show in Finder")
        }
        .padding(12)
        .cardEffect(isSelected: false)
        .onHover { hovering in
            withAnimation(DesignConstants.Animation.quick) {
                isHovered = hovering
            }
        }
        .task {
            await calculateFileSize()
        }
    }
    
    private func showInFinder() {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        
        if FileManager.default.fileExists(atPath: expandedPath) {
            NSWorkspace.shared.selectFile(
                expandedPath,
                inFileViewerRootedAtPath: url.deletingLastPathComponent().path
            )
        } else {
            let parentURL = url.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: parentURL.path) {
                NSWorkspace.shared.open(parentURL)
            }
        }
    }
    
    private func calculateFileSize() async {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        
        await MainActor.run {
            do {
                let resourceValues = try url.resourceValues(
                    forKeys: [.totalFileSizeKey, .fileSizeKey, .isDirectoryKey]
                )
                
                let size: Int64
                if resourceValues.isDirectory == true {
                    size = directorySize(at: url)
                } else {
                    size = Int64(resourceValues.totalFileSize ?? resourceValues.fileSize ?? 0)
                }
                
                self.fileSize = formatFileSize(size)
            } catch {
                self.fileSize = "Not Found"
            }
        }
    }
    
    private func directorySize(at url: URL) -> Int64 {
        var totalSize: Int64 = 0
        
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileSizeKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(
                    forKeys: [.totalFileSizeKey, .fileSizeKey]
                )
                let fileSize = Int64(resourceValues.totalFileSize ?? resourceValues.fileSize ?? 0)
                totalSize += fileSize
            } catch {
                continue
            }
        }
        
        return totalSize
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - BackupPlaceholderView

struct BackupPlaceholderView: View {
    @ObservedObject var backupManager: BackupManager
    @Binding var isProcessing: Bool
    @Binding var progress: Double
    @Environment(\.colorScheme) var colorScheme
    
    private var hasValidSelection: Bool {
        !backupManager.apps.filter { $0.isSelected && $0.isInstalled }.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "arrowshape.turn.up.left.2.fill")
                    .font(.system(size: 108))
                    .foregroundColor(Color.App.accent.color(for: colorScheme).opacity(0.7))
                
                Text(NSLocalizedString("Detail_Placeholder_Select_App", comment: ""))
                    .font(DesignConstants.Typography.headline)
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
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
    }
    
    private func performQuickBackup() {
        withAnimation(DesignConstants.Animation.standard) {
            isProcessing = true
            progress = 0.0
        }
        
        Task { @MainActor in
            while progress < 0.98 {
                try? await Task.sleep(for: .milliseconds(30))
                progress += 0.0294
            }
            
            backupManager.performBackup()
            
            progress = 1.0
            try? await Task.sleep(for: .seconds(0.5))
            
            isProcessing = false
            progress = 0.0
        }
    }
}

// MARK: - RestorePlaceholderView

struct RestorePlaceholderView: View {
    @ObservedObject var backupManager: BackupManager
    @Binding var isProcessing: Bool
    @Binding var progress: Double
    @Environment(\.colorScheme) var colorScheme
    
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
    }
}

// MARK: - RestoreDetailContent

struct RestoreDetailContent: View {
    @ObservedObject var backupManager: BackupManager
    let backup: BackupInfo
    @Binding var isProcessing: Bool
    @Binding var progress: Double
    @Environment(\.colorScheme) var colorScheme
    
    private var selectedAppsCount: Int {
        backupManager.selectedBackup?.apps.filter { $0.isSelected }.count ?? 0
    }
    
    private var uninstalledSelectedCount: Int {
        backupManager.selectedBackup?.apps.filter {
            !$0.isCurrentlyInstalled && $0.isSelected
        }.count ?? 0
    }
    
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
                        .foregroundColor(Color.App.accent.color(for: colorScheme))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatBackupName(backup.name))
                            .font(DesignConstants.Typography.title)
                        
                        Text(String(
                            format: NSLocalizedString("Detail_Restore_Backup_App_Count", comment: ""),
                            backup.apps.count
                        ))
                        .font(DesignConstants.Typography.caption)
                        .foregroundColor(Color.App.secondary.color(for: colorScheme))
                    }
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        String(
                            format: NSLocalizedString("Detail_Restore_Selected_Apps_Count", comment: ""),
                            selectedAppsCount
                        ),
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(DesignConstants.Typography.body)
                    .foregroundColor(
                        selectedAppsCount > 0
                            ? Color.App.success.color(for: colorScheme)
                            : Color.App.secondary.color(for: colorScheme)
                    )
                    
                    Label(
                        String(
                            format: NSLocalizedString("Detail_Restore_Uninstalled_Apps_Count", comment: ""),
                            uninstalledSelectedCount
                        ),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(DesignConstants.Typography.body)
                    .foregroundColor(
                        uninstalledSelectedCount > 0
                            ? Color.App.warning.color(for: colorScheme)
                            : Color.App.secondary.color(for: colorScheme)
                    )
                }
            }
            .padding(20)
            .background(Color.App.contentAreaBackground.color(for: colorScheme))
            
            // Selected apps list
            if hasSelectedApps {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("Detail_Restore_Will_Restore_Apps", comment: ""))
                            .font(DesignConstants.Typography.headline)
                            .padding(.bottom, 8)
                        
                        ForEach(backupManager.selectedBackup?.apps.filter { $0.isSelected } ?? []) { app in
                            HStack {
                                Image(systemName: app.isCurrentlyInstalled
                                    ? "checkmark.circle"
                                    : "exclamationmark.circle")
                                    .foregroundColor(
                                        app.isCurrentlyInstalled
                                            ? Color.App.success.color(for: colorScheme)
                                            : Color.App.warning.color(for: colorScheme)
                                    )
                                
                                Text(app.name)
                                    .font(DesignConstants.Typography.body)
                                
                                if !app.isCurrentlyInstalled {
                                    Text(NSLocalizedString("Detail_Restore_App_Not_Installed_Badge", comment: ""))
                                        .font(DesignConstants.Typography.caption)
                                        .foregroundColor(Color.App.warning.color(for: colorScheme))
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(16)
                }
            } else {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 48))
                        .foregroundColor(Color.App.accent.color(for: colorScheme).opacity(0.6))
                    
                    Text(NSLocalizedString("Detail_Restore_No_Apps_Selected", comment: ""))
                        .font(DesignConstants.Typography.headline)
                        .foregroundColor(Color.App.secondary.color(for: colorScheme))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Spacer()
            
            // Action bar
            HStack {
                Spacer()
                
                Button(action: performRestore) {
                    Label(
                        NSLocalizedString("Detail_Restore_Action_Restore_Selected", comment: ""),
                        systemImage: "arrow.down.circle.fill"
                    )
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!hasSelectedApps)
            }
            .padding(20)
        }
    }
    
    private func performRestore() {
        withAnimation(DesignConstants.Animation.standard) {
            isProcessing = true
            progress = 0.0
        }
        
        Task { @MainActor in
            while progress < 0.98 {
                try? await Task.sleep(for: .milliseconds(30))
                progress += 0.0294
            }
            
            // Call performRestore without parameters
            backupManager.performRestore()
            
            progress = 1.0
            try? await Task.sleep(for: .seconds(0.5))
            
            isProcessing = false
            progress = 0.0
        }
    }
    
    private func formatBackupName(_ name: String) -> String {
        name.replacingOccurrences(of: ".zip", with: "")
    }
}

// MARK: - RestoreEmptyDetail

struct RestoreEmptyDetail: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 108))
                .foregroundColor(Color.App.accent.color(for: colorScheme).opacity(0.7))
            
            Text(NSLocalizedString("Detail_Restore_Placeholder_Select_Backup", comment: ""))
                .font(DesignConstants.Typography.headline)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
