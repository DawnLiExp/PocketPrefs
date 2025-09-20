//
//  BackupManager.swift
//  PocketPrefs
//
//  Main backup manager coordinating all operations
//

import Foundation
import os.log
import SwiftUI

@MainActor
class BackupManager: ObservableObject {
    @Published var apps: [AppConfig] = []
    @Published var isProcessing = false
    @Published var statusMessage = ""
    @Published var currentProgress: Double = 0.0
    
    // Restore mode
    @Published var availableBackups: [BackupInfo] = []
    @Published var selectedBackup: BackupInfo?
    
    private let logger = Logger(subsystem: "com.pocketprefs", category: "BackupManager")
    private let iconService = IconService.shared
    private let backupService = BackupService()
    private let restoreService = RestoreService()
    private let fileOps = FileOperationService.shared
    
    init() {
        Task {
            await loadApps()
            await scanBackups()
        }
    }
    
    // Load and check apps
    func loadApps() async {
        apps = AppConfig.presetConfigs
        
        // Check installation status concurrently
        await withTaskGroup(of: (UUID, Bool).self) { group in
            for app in apps {
                group.addTask { [weak self] in
                    guard let self = self else { return (app.id, false) }
                    let isInstalled = await self.fileOps.checkIfAppInstalled(bundleId: app.bundleId)
                    return (app.id, isInstalled)
                }
            }
            
            for await (appId, isInstalled) in group {
                if let index = self.apps.firstIndex(where: { $0.id == appId }) {
                    self.apps[index].isInstalled = isInstalled
                    self.apps[index].isSelected = isInstalled // Default select installed apps
                }
            }
        }
        
        logger.info("Loaded \(self.apps.count) apps")
    }
    
    // Get icon for app
    func getIcon(for app: AppConfig) -> NSImage {
        iconService.getIcon(for: app.bundleId, category: app.category)
    }
    
    // Get icon for backup app
    func getIcon(for backupApp: BackupAppInfo) -> NSImage {
        iconService.getIcon(for: backupApp.bundleId, category: backupApp.category)
    }
    
    // Scan for existing backups
    func scanBackups() async {
        availableBackups = await backupService.scanBackups()
        
        if let firstBackup = availableBackups.first {
            selectBackup(firstBackup)
        }
        
        logger.info("Found \(self.availableBackups.count) backups")
    }
    
    // Select a backup
    func selectBackup(_ backup: BackupInfo) {
        selectedBackup = backup
    }
    
    // Toggle app selection
    func toggleSelection(for app: AppConfig) {
        if let index = apps.firstIndex(where: { $0.id == app.id }) {
            apps[index].isSelected.toggle()
        }
    }
    
    // Select all apps
    func selectAll() {
        for index in apps.indices where apps[index].isInstalled {
            apps[index].isSelected = true
        }
    }
    
    // Deselect all apps
    func deselectAll() {
        for index in apps.indices {
            apps[index].isSelected = false
        }
    }
    
    // Toggle restore selection
    func toggleRestoreSelection(for app: BackupAppInfo) {
        guard let currentBackup = selectedBackup,
              let backupIndex = availableBackups.firstIndex(where: { $0.id == currentBackup.id }),
              let appIndex = availableBackups[backupIndex].apps.firstIndex(where: { $0.id == app.id })
        else { return }
        
        availableBackups[backupIndex].apps[appIndex].isSelected.toggle()
        
        // Update selectedBackup to trigger UI update
        selectedBackup = availableBackups[backupIndex]
        objectWillChange.send()
    }
    
    // Perform backup
    func performBackup() {
        Task {
            await performBackupAsync()
        }
    }
    
    private func performBackupAsync() async {
        isProcessing = true
        currentProgress = 0.0
        statusMessage = NSLocalizedString("Backup_Starting", comment: "")
        
        // Monitor progress
        let progressTask = Task { [weak self] in
            var progress = 0.0
            while progress < 0.9 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                progress += 0.02
                await MainActor.run {
                    self?.currentProgress = min(progress, 0.9)
                }
            }
        }
        
        let result = await backupService.performBackup(apps: apps)
        progressTask.cancel()
        
        currentProgress = 1.0
        statusMessage = result.statusMessage
        
        // Refresh backups list
        await scanBackups()
        
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        isProcessing = false
        currentProgress = 0.0
    }
    
    // Perform restore
    func performRestore(from path: String) {
        guard let backup = selectedBackup else {
            logger.error("No backup selected for restore")
            return
        }
        
        Task {
            await performRestoreAsync(backup: backup)
        }
    }
    
    private func performRestoreAsync(backup: BackupInfo) async {
        isProcessing = true
        currentProgress = 0.0
        statusMessage = NSLocalizedString("Restore_Starting", comment: "")
        
        // Monitor progress
        let progressTask = Task { [weak self] in
            var progress = 0.0
            while progress < 0.9 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                progress += 0.02
                await MainActor.run {
                    self?.currentProgress = min(progress, 0.9)
                }
            }
        }
        
        let result = await restoreService.performRestore(backup: backup)
        progressTask.cancel()
        
        currentProgress = 1.0
        statusMessage = result.statusMessage
        
        // Refresh app installation status
        await loadApps()
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        isProcessing = false
        currentProgress = 0.0
    }
    
    // Scan apps in backup (for file picker)
    func scanAppsInBackup(at path: String) -> [BackupAppInfo] {
        // Create a synchronous wrapper for the async operation
        var result: [BackupAppInfo] = []
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            result = await backupService.scanAppsInBackup(at: path)
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
}
