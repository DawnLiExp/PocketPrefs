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
    private let userStore = UserConfigStore.shared
    
    init() {
        Task {
            await loadApps()
            await scanBackups()
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(customAppsChanged),
            name: .customAppsChanged,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func customAppsChanged() {
        Task {
            await loadApps()
        }
    }
    
    func loadApps() async {
        var allApps = AppConfig.presetConfigs
        allApps.append(contentsOf: userStore.customApps)

        await withTaskGroup(of: (UUID, Bool).self) { group in
            for app in allApps {
                group.addTask { [weak self] in
                    guard let self = self else { return (app.id, false) }
                    let isInstalled = await self.fileOps.checkIfAppInstalled(bundleId: app.bundleId)
                    return (app.id, isInstalled)
                }
            }
            
            var updatedApps = allApps
            for await (appId, isInstalled) in group {
                if let index = updatedApps.firstIndex(where: { $0.id == appId }) {
                    updatedApps[index].isInstalled = isInstalled
                    updatedApps[index].isSelected = false
                }
            }
            
            self.apps = updatedApps
        }
        
        logger.info("Loaded \(self.apps.count) apps (including \(self.userStore.customApps.count) custom apps)")
    }
    
    func getIcon(for app: AppConfig) -> NSImage {
        iconService.getIcon(for: app.bundleId, category: app.category)
    }
    
    func getIcon(for backupApp: BackupAppInfo) -> NSImage {
        iconService.getIcon(for: backupApp.bundleId, category: backupApp.category)
    }
    
    func scanBackups() async {
        availableBackups = await backupService.scanBackups()
        
        // Update selection state
        if let currentSelected = selectedBackup, !availableBackups.contains(currentSelected) {
            selectedBackup = nil
        }
        
        if selectedBackup == nil, let firstBackup = availableBackups.first {
            selectBackup(firstBackup)
        }
        
        logger.info("Found \(self.availableBackups.count) backups")
    }
    
    func selectBackup(_ backup: BackupInfo) {
        selectedBackup = backup
    }
    
    func toggleSelection(for app: AppConfig) {
        if let index = apps.firstIndex(where: { $0.id == app.id }) {
            apps[index].isSelected.toggle()
        }
    }
    
    func selectAll() {
        for index in apps.indices where apps[index].isInstalled {
            apps[index].isSelected = true
        }
    }
    
    func deselectAll() {
        for index in apps.indices {
            apps[index].isSelected = false
        }
    }
    
    func toggleRestoreSelection(for app: BackupAppInfo) {
        guard let currentBackup = selectedBackup,
              let backupIndex = availableBackups.firstIndex(where: { $0.id == currentBackup.id }),
              let appIndex = availableBackups[backupIndex].apps.firstIndex(where: { $0.id == app.id })
        else { return }
        
        availableBackups[backupIndex].apps[appIndex].isSelected.toggle()
        selectedBackup = availableBackups[backupIndex]
        objectWillChange.send()
    }
    
    func performBackup() {
        Task {
            await performBackupAsync()
        }
    }
    
    private func performBackupAsync() async {
        isProcessing = true
        currentProgress = 0.0
        statusMessage = NSLocalizedString("Backup_Starting", comment: "")
        
        // Start progress monitoring with structured concurrency
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                await self?.monitorProgress(targetProgress: 0.98, duration: 3.0)
            }
            
            // Backup operation task
            group.addTask { [weak self] in
                guard let self = self else { return }
                let result = await self.backupService.performBackup(apps: self.apps)
                
                await MainActor.run {
                    // Ensure progress reaches 100%
                    self.currentProgress = 1.0
                    self.statusMessage = result.statusMessage
                }
                
                // Allow animation to complete at 100%
                try? await Task.sleep(for: .seconds(0.5))
                
                await self.scanBackups()
            }
            
            // Wait for all tasks to complete
            await group.waitForAll()
        }
        
        // Final cleanup with additional pause
        try? await Task.sleep(for: .seconds(0.3))
        isProcessing = false
        currentProgress = 0.0
    }
    
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
        
        // Start progress monitoring with structured concurrency
        await withTaskGroup(of: Void.self) { group in
            // Progress monitoring task - monitor to 0.98 for visual completion
            group.addTask { [weak self] in
                await self?.monitorProgress(targetProgress: 0.98, duration: 3.0)
            }
            
            // Restore operation task
            group.addTask { [weak self] in
                guard let self = self else { return }
                let result = await self.restoreService.performRestore(backup: backup)
                
                await MainActor.run {
                    // Ensure progress reaches 100%
                    self.currentProgress = 1.0
                    self.statusMessage = result.statusMessage
                }
                
                // Allow animation to complete at 100%
                try? await Task.sleep(for: .seconds(0.5))
                
                await self.loadApps()
            }
            
            // Wait for all tasks to complete
            await group.waitForAll()
        }
        
        // Final cleanup with additional pause
        try? await Task.sleep(for: .seconds(0.3))
        isProcessing = false
        currentProgress = 0.0
    }
    
    // Progress monitoring helper using structured concurrency
    private func monitorProgress(targetProgress: Double, duration: TimeInterval) async {
        let steps = 40
        let stepDuration = duration / Double(steps)
        let progressIncrement = targetProgress / Double(steps)
        
        for step in 0 ..< steps {
            guard !Task.isCancelled else { break }
            
            let newProgress = Double(step + 1) * progressIncrement
            currentProgress = min(newProgress, targetProgress)
            
            try? await Task.sleep(for: .seconds(stepDuration))
        }
    }
    
    // Scan apps in backup - async only
    func scanAppsInBackup(at path: String) async -> [BackupAppInfo] {
        await backupService.scanAppsInBackup(at: path)
    }
}
