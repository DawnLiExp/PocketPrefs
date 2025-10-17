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
    // MARK: - Internal State
    
    private var apps: [AppConfig] = []
    
    // MARK: - Published State
    
    @Published private(set) var availableBackups: [BackupInfo] = []
    @Published private(set) var selectedBackup: BackupInfo?
    
    // MARK: - Services
    
    private let logger = Logger(subsystem: "com.pocketprefs", category: "MainCoordinator")
    private let iconService = IconService.shared
    private let backupService = BackupService()
    private let restoreService = RestoreService()
    private let fileOps = FileOperationService.shared
    private let userStore = UserConfigStore.shared
    
    // MARK: - Tasks Management
    
    private var tasks: [Task<Void, Never>] = []
    
    // MARK: - Initialization
    
    init() {
        Task {
            await loadApps()
            await scanBackups()
        }
        
        subscribeToEvents()
    }
    
    deinit {
        tasks.forEach { $0.cancel() }
    }
    
    // MARK: - Public Accessors
    
    var currentApps: [AppConfig] { apps }
    var currentBackups: [BackupInfo] { availableBackups }
    var currentSelectedBackup: BackupInfo? { selectedBackup }
    
    // MARK: - Event Subscriptions
    
    private func subscribeToEvents() {
        tasks.append(Task { await subscribeToUserConfigEvents() })
        tasks.append(Task { await subscribeToSettingsEvents() })
        tasks.append(Task { await subscribeToPreferencesEvents() })
        tasks.append(Task { await subscribeToIconEvents() })
    }
    
    private func subscribeToUserConfigEvents() async {
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
            
            await loadApps()
        }
    }
    
    private func subscribeToSettingsEvents() async {
        let eventStream = SettingsEventPublisher.shared.subscribe()
        
        for await event in eventStream {
            guard !Task.isCancelled else { break }
            
            if case .didClose = event {
                logger.info("Settings closed - reloading apps")
                await loadApps()
            }
        }
    }
    
    private func subscribeToPreferencesEvents() async {
        for await event in PreferencesManager.shared.events {
            guard !Task.isCancelled else { break }
            
            if case .directoryChanged(let path) = event {
                logger.info("Backup directory changed: \(path)")
                await handleDirectoryChange()
            }
        }
    }
    
    private func subscribeToIconEvents() async {
        var loadedIcons: Set<String> = []
        
        for await bundleId in iconService.events {
            guard !Task.isCancelled else { break }
            loadedIcons.insert(bundleId)
            
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { break }
            
            if !loadedIcons.isEmpty {
                logger.debug("Batch icon update: \(loadedIcons.count) icons loaded")
                loadedIcons.removeAll()
                objectWillChange.send()
            }
        }
    }
    
    private func handleDirectoryChange() async {
        logger.info("Handling backup directory change")
        selectedBackup = nil
        availableBackups = []
        await scanBackups()
    }
    
    // MARK: - App Management
    
    func loadApps() async {
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
            apps = updatedApps
            publishEvent(.appsUpdated(updatedApps))
        }
        
        logger.info("Loaded \(self.apps.count) apps (\(self.userStore.customApps.count) custom)")
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
        
        publishEvent(.backupsUpdated(backups))
        logger.info("Found \(self.availableBackups.count) backups")
    }
    
    func selectBackup(_ backup: BackupInfo) {
        selectedBackup = backup
        publishEvent(.selectedBackupUpdated(backup))
    }
    
    func selectIncrementalBase(_ backup: BackupInfo) {
        // Managed by MainViewModel
    }
    
    // MARK: - Selection Management
    
    func toggleSelection(for app: AppConfig) {
        guard let index = apps.firstIndex(where: { $0.id == app.id }) else { return }
        apps[index].isSelected.toggle()
        publishEvent(.appsUpdated(apps))
    }
    
    func selectAll() {
        apps = apps.map { app in
            var updated = app
            if updated.isInstalled {
                updated.isSelected = true
            }
            return updated
        }
        publishEvent(.appsUpdated(apps))
    }
    
    func deselectAll() {
        apps = apps.map { app in
            var updated = app
            updated.isSelected = false
            return updated
        }
        publishEvent(.appsUpdated(apps))
    }
    
    func toggleRestoreSelection(for app: BackupAppInfo) {
        modifyBackupApps { apps in
            guard let index = apps.firstIndex(where: { $0.id == app.id }) else { return }
            apps[index].isSelected.toggle()
        }
    }
    
    func selectAllRestoreApps() {
        modifyBackupApps { apps in
            apps = apps.map { app in
                var updated = app
                updated.isSelected = true
                return updated
            }
        }
    }
    
    func deselectAllRestoreApps() {
        modifyBackupApps { apps in
            apps = apps.map { app in
                var updated = app
                updated.isSelected = false
                return updated
            }
        }
    }
    
    // MARK: - Operations
    
    func performBackupOperation(
        incrementalBase: BackupInfo?,
        onProgress: @escaping @Sendable (ProgressUpdate) async -> Void,
    ) async {
        let startTime = Date()
        
        publishEvent(.operationStarted)
        
        await onProgress(ProgressUpdate(
            fraction: 0.0,
            message: NSLocalizedString("Backup_Starting", comment: ""),
        ))
        
        let result = await backupService.performBackup(
            apps: apps,
            incrementalBase: incrementalBase,
            onProgress: onProgress,
        )
        
        await enforceMinimumDuration(startTime: startTime, onProgress: onProgress, result: result.statusMessage)
        
        await scanBackups()
        
        try? await Task.sleep(for: .seconds(0.2))
        publishEvent(.operationCompleted)
    }
    
    func performRestoreOperation(
        onProgress: @escaping @Sendable (ProgressUpdate) async -> Void,
    ) async {
        guard let backup = selectedBackup else {
            logger.error("No backup selected for restore")
            return
        }
        
        let startTime = Date()
        
        publishEvent(.operationStarted)
        
        await onProgress(ProgressUpdate(
            fraction: 0.0,
            message: NSLocalizedString("Restore_Starting", comment: ""),
        ))
        
        let result = await restoreService.performRestore(
            backup: backup,
            onProgress: onProgress,
        )
        
        await enforceMinimumDuration(startTime: startTime, onProgress: onProgress, result: result.statusMessage)
        
        await loadApps()
        
        try? await Task.sleep(for: .seconds(0.2))
        publishEvent(.operationCompleted)
    }
    
    func scanAppsInBackup(at path: String) async -> [BackupAppInfo] {
        await backupService.scanAppsInBackup(at: path)
    }
    
    // MARK: - Private Helpers
    
    private func modifyBackupApps(_ modify: (inout [BackupAppInfo]) -> Void) {
        guard let currentBackup = selectedBackup,
              let backupIndex = availableBackups.firstIndex(where: { $0.id == currentBackup.id })
        else { return }
        
        modify(&availableBackups[backupIndex].apps)
        selectedBackup = availableBackups[backupIndex]
        
        publishBackupUpdates()
    }
    
    private func publishEvent(_ event: CoordinatorEvent) {
        CoordinatorEventPublisher.shared.publish(event)
    }
    
    private func publishBackupUpdates() {
        publishEvent(.backupsUpdated(availableBackups))
        publishEvent(.selectedBackupUpdated(selectedBackup))
    }
    
    private func enforceMinimumDuration(
        startTime: Date,
        onProgress: @escaping @Sendable (ProgressUpdate) async -> Void,
        result: String,
    ) async {
        let elapsed = Date().timeIntervalSince(startTime)
        let minDuration = 1.3
        if elapsed < minDuration {
            try? await Task.sleep(for: .seconds(minDuration - elapsed))
        }
        
        await onProgress(ProgressUpdate(
            fraction: 1.0,
            message: result,
        ))
        
        try? await Task.sleep(for: .seconds(0.5))
    }
}
