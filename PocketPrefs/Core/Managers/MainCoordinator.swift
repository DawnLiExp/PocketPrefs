//
//  MainCoordinator.swift
//  PocketPrefs
//
//  Core business logic coordination with event-driven architecture
//

import Foundation
import os.log
import SwiftUI

@MainActor
final class MainCoordinator: ObservableObject {
    // MARK: - Internal State (not published)
    
    private var apps: [AppConfig] = []
    var availableBackups: [BackupInfo] = []
    private var selectedBackup: BackupInfo?
    
    // MARK: - Services
    
    private let logger = Logger(subsystem: "com.pocketprefs", category: "MainCoordinator")
    private let iconService = IconService.shared
    private let backupService = BackupService()
    private let restoreService = RestoreService()
    private let fileOps = FileOperationService.shared
    private let userStore = UserConfigStore.shared
    
    // MARK: - Tasks
    
    private var prefsEventTask: Task<Void, Never>?
    private var iconEventTask: Task<Void, Never>?
    private var userConfigEventTask: Task<Void, Never>?
    private var loadAppsTask: Task<Void, Never>?
    private var scanBackupsTask: Task<Void, Never>?
    private var settingsEventTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init() {
        Task {
            await loadApps()
            await scanBackups()
        }
        
        subscribeToPreferencesEvents()
        subscribeToIconEvents()
        subscribeToUserConfigEvents()
        subscribeToSettingsEvents()
    }
    
    deinit {
        prefsEventTask?.cancel()
        iconEventTask?.cancel()
        userConfigEventTask?.cancel()
        loadAppsTask?.cancel()
        scanBackupsTask?.cancel()
        settingsEventTask?.cancel()
    }
    
    // MARK: - Public Accessors
    
    var currentApps: [AppConfig] { apps }
    var currentBackups: [BackupInfo] { availableBackups }
    var currentSelectedBackup: BackupInfo? { selectedBackup }
    
    // MARK: - Event Subscriptions
    
    private func subscribeToUserConfigEvents() {
        userConfigEventTask?.cancel()
        userConfigEventTask = Task { [weak self] in
            guard let self else { return }
            let eventStream = userStore.subscribe()
            
            for await event in eventStream {
                guard !Task.isCancelled else { break }
                
                switch event {
                case .appAdded(let app):
                    logger.info("User config event: app added - \(app.name)")
                case .appUpdated(let app):
                    logger.info("User config event: app updated - \(app.name)")
                case .appsRemoved(let ids):
                    logger.info("User config event: apps removed - \(ids.count) apps")
                case .batchUpdated(let apps):
                    logger.info("User config event: batch update - \(apps.count) apps")
                }
                
                await self.loadApps()
            }
        }
    }
    
    private func subscribeToSettingsEvents() {
        settingsEventTask?.cancel()
        settingsEventTask = Task { [weak self] in
            guard let self else { return }
            let eventStream = SettingsEventPublisher.shared.subscribe()
            
            for await event in eventStream {
                guard !Task.isCancelled else { break }
                
                if case .didClose = event {
                    await self.handleSettingsClose()
                }
            }
        }
    }
    
    private func handleSettingsClose() async {
        logger.info("Settings closed event received")
        await loadApps()
        logger.info("Settings close sync completed")
    }
    
    private func subscribeToPreferencesEvents() {
        prefsEventTask?.cancel()
        prefsEventTask = Task { [weak self] in
            guard let self else { return }
            
            for await event in PreferencesManager.shared.events {
                guard !Task.isCancelled else { break }
                
                if case .directoryChanged(let path) = event {
                    logger.info("Backup directory changed: \(path)")
                    await self.handleDirectoryChange()
                }
            }
        }
    }
    
    private func subscribeToIconEvents() {
        iconEventTask?.cancel()
        iconEventTask = Task { [weak self] in
            guard let self else { return }
            var loadedIcons: Set<String> = []
            
            for await bundleId in iconService.events {
                guard !Task.isCancelled else { break }
                loadedIcons.insert(bundleId)
                
                try? await Task.sleep(for: .seconds(0.5))
                guard !Task.isCancelled else { break }
                
                if !loadedIcons.isEmpty {
                    logger.debug("Batch icon update: \(loadedIcons.count) icons loaded")
                    loadedIcons.removeAll()
                    self.objectWillChange.send()
                }
            }
        }
    }
    
    private func handleDirectoryChange() async {
        logger.info("Handling backup directory change")
        
        selectedBackup = nil
        availableBackups = []
        
        await scanBackups()
        logger.info("Rescan completed: \(self.availableBackups.count) backups found")
    }
    
    // MARK: - App Management
    
    func loadApps() async {
        loadAppsTask?.cancel()
        
        loadAppsTask = Task {
            var allApps = AppConfig.presetConfigs
            allApps.append(contentsOf: userStore.customApps)
            
            await withTaskGroup(of: (UUID, Bool).self) { group in
                for app in allApps {
                    group.addTask { [weak self] in
                        guard let self else { return (app.id, false) }
                        let isInstalled = await self.fileOps.checkIfAppInstalled(bundleId: app.bundleId)
                        return (app.id, isInstalled)
                    }
                }
                
                var updatedApps = allApps
                for await (appId, isInstalled) in group {
                    guard !Task.isCancelled else { break }
                    
                    if let index = updatedApps.firstIndex(where: { $0.id == appId }) {
                        updatedApps[index].isInstalled = isInstalled
                        updatedApps[index].isSelected = false
                    }
                }
                
                guard !Task.isCancelled else { return }
                self.apps = updatedApps
                CoordinatorEventPublisher.shared.publish(.appsUpdated(updatedApps))
            }
            
            logger.info("Loaded \(self.apps.count) apps (\(self.userStore.customApps.count) custom)")
        }
        
        await loadAppsTask?.value
    }
    
    // MARK: - Icon Management
    
    func getIcon(for app: AppConfig) -> NSImage {
        iconService.getIcon(for: app.bundleId, category: app.category)
    }
    
    func getIcon(for backupApp: BackupAppInfo) -> NSImage {
        iconService.getIcon(for: backupApp.bundleId, category: backupApp.category)
    }
    
    // MARK: - Backup Management
    
    func scanBackups() async {
        scanBackupsTask?.cancel()
        
        scanBackupsTask = Task {
            let backups = await backupService.scanBackups()
            guard !Task.isCancelled else { return }
            
            availableBackups = backups
            
            if let currentSelected = selectedBackup,
               !availableBackups.contains(currentSelected)
            {
                selectedBackup = nil
            }
            
            if selectedBackup == nil, let firstBackup = availableBackups.first {
                selectBackup(firstBackup)
            }
            
            CoordinatorEventPublisher.shared.publish(.backupsUpdated(backups))
            
            logger.info("Found \(self.availableBackups.count) backups")
        }
        
        await scanBackupsTask?.value
    }
    
    func selectBackup(_ backup: BackupInfo) {
        selectedBackup = backup
        CoordinatorEventPublisher.shared.publish(.selectedBackupUpdated(backup))
    }
    
    func selectIncrementalBase(_ backup: BackupInfo) {
        // Incremental base is managed by MainViewModel
        // This method exists for coordination if needed
    }
    
    // MARK: - Selection Management
    
    func toggleSelection(for app: AppConfig) {
        if let index = apps.firstIndex(where: { $0.id == app.id }) {
            apps[index].isSelected.toggle()
            CoordinatorEventPublisher.shared.publish(.appsUpdated(apps))
        }
    }
    
    func selectAll() {
        apps = apps.map { app in
            var updated = app
            if updated.isInstalled {
                updated.isSelected = true
            }
            return updated
        }
        CoordinatorEventPublisher.shared.publish(.appsUpdated(apps))
    }
    
    func deselectAll() {
        apps = apps.map { app in
            var updated = app
            updated.isSelected = false
            return updated
        }
        CoordinatorEventPublisher.shared.publish(.appsUpdated(apps))
    }
    
    func toggleRestoreSelection(for app: BackupAppInfo) {
        guard let currentBackup = selectedBackup,
              let backupIndex = availableBackups.firstIndex(where: { $0.id == currentBackup.id }),
              let appIndex = availableBackups[backupIndex].apps.firstIndex(where: { $0.id == app.id })
        else { return }
        
        availableBackups[backupIndex].apps[appIndex].isSelected.toggle()
        selectedBackup = availableBackups[backupIndex]
        
        // Publish both events to ensure all ViewModels update
        CoordinatorEventPublisher.shared.publish(.backupsUpdated(availableBackups))
        CoordinatorEventPublisher.shared.publish(.selectedBackupUpdated(selectedBackup))
    }
    
    func selectAllRestoreApps() {
        guard let currentBackup = selectedBackup,
              let backupIndex = availableBackups.firstIndex(where: { $0.id == currentBackup.id })
        else { return }
        
        availableBackups[backupIndex].apps = availableBackups[backupIndex].apps.map { app in
            var updated = app
            updated.isSelected = true
            return updated
        }
        
        selectedBackup = availableBackups[backupIndex]
        
        CoordinatorEventPublisher.shared.publish(.backupsUpdated(availableBackups))
        CoordinatorEventPublisher.shared.publish(.selectedBackupUpdated(selectedBackup))
    }
    
    func deselectAllRestoreApps() {
        guard let currentBackup = selectedBackup,
              let backupIndex = availableBackups.firstIndex(where: { $0.id == currentBackup.id })
        else { return }
        
        availableBackups[backupIndex].apps = availableBackups[backupIndex].apps.map { app in
            var updated = app
            updated.isSelected = false
            return updated
        }
        
        selectedBackup = availableBackups[backupIndex]
        
        CoordinatorEventPublisher.shared.publish(.backupsUpdated(availableBackups))
        CoordinatorEventPublisher.shared.publish(.selectedBackupUpdated(selectedBackup))
    }
    
    // MARK: - Operations
    
    func performBackupOperation(
        incrementalBase: BackupInfo?,
        onProgress: @escaping @Sendable (ProgressUpdate) async -> Void,
    ) async {
        let startTime = Date()
        
        CoordinatorEventPublisher.shared.publish(.operationStarted)
        
        await onProgress(ProgressUpdate(
            fraction: 0.0,
            message: NSLocalizedString("Backup_Starting", comment: ""),
        ))
        
        let result = await backupService.performBackup(
            apps: apps,
            incrementalBase: incrementalBase,
            onProgress: onProgress,
        )
        
        let elapsed = Date().timeIntervalSince(startTime)
        let minDuration = 1.3
        if elapsed < minDuration {
            try? await Task.sleep(for: .seconds(minDuration - elapsed))
        }
        
        await onProgress(ProgressUpdate(
            fraction: 1.0,
            message: result.statusMessage,
        ))
        
        try? await Task.sleep(for: .seconds(0.5))
        await scanBackups()
        
        try? await Task.sleep(for: .seconds(0.2))
        CoordinatorEventPublisher.shared.publish(.operationCompleted)
    }
    
    func performRestoreOperation(
        onProgress: @escaping @Sendable (ProgressUpdate) async -> Void,
    ) async {
        guard let backup = selectedBackup else {
            logger.error("No backup selected for restore")
            return
        }
        
        let startTime = Date()
        
        CoordinatorEventPublisher.shared.publish(.operationStarted)
        
        await onProgress(ProgressUpdate(
            fraction: 0.0,
            message: NSLocalizedString("Restore_Starting", comment: ""),
        ))
        
        let result = await restoreService.performRestore(
            backup: backup,
            onProgress: onProgress,
        )
        
        let elapsed = Date().timeIntervalSince(startTime)
        let minDuration = 1.3
        if elapsed < minDuration {
            try? await Task.sleep(for: .seconds(minDuration - elapsed))
        }
        
        await onProgress(ProgressUpdate(
            fraction: 1.0,
            message: result.statusMessage,
        ))
        
        try? await Task.sleep(for: .seconds(0.5))
        await loadApps()
        
        try? await Task.sleep(for: .seconds(0.2))
        CoordinatorEventPublisher.shared.publish(.operationCompleted)
    }
    
    func scanAppsInBackup(at path: String) async -> [BackupAppInfo] {
        await backupService.scanAppsInBackup(at: path)
    }
}
