//
//  MainCoordinator.swift
//  PocketPrefs
//
//  Core business logic coordinator with structured concurrency
//

import Foundation
import os.log
import SwiftUI

@MainActor
final class MainCoordinator: ObservableObject {
    @Published var apps: [AppConfig] = []
    @Published var isProcessing = false
    @Published var statusMessage = ""
    @Published var currentProgress: Double = 0.0
    @Published var statusMessageHistory: [String] = []
    @Published var availableBackups: [BackupInfo] = []
    @Published var selectedBackup: BackupInfo?
    @Published var isIncrementalMode = false
    @Published var incrementalBaseBackup: BackupInfo?
    
    private let logger = Logger(subsystem: "com.pocketprefs", category: "MainCoordinator")
    private let iconService = IconService.shared
    private let backupService = BackupService()
    private let restoreService = RestoreService()
    private let fileOps = FileOperationService.shared
    private let userStore = UserConfigStore.shared
    
    private var prefsEventTask: Task<Void, Never>?
    private var iconEventTask: Task<Void, Never>?
    private var userConfigEventTask: Task<Void, Never>?
    private var loadAppsTask: Task<Void, Never>?
    private var scanBackupsTask: Task<Void, Never>?
    private var settingsEventTask: Task<Void, Never>?
    
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
    
    // MARK: - Event Subscriptions
    
    /// Subscribe to user config store events
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
    
    /// Subscribe to settings window events
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
    
    /// Handle settings window close event
    private func handleSettingsClose() async {
        logger.info("Settings closed event received")
        await loadApps()
        logger.info("Settings close sync completed")
    }
    
    /// Subscribe to preferences directory change events
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
    
    /// Subscribe to icon loading events with batching
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
    
    /// Handle backup directory change
    private func handleDirectoryChange() async {
        logger.info("Handling backup directory change")
        
        selectedBackup = nil
        incrementalBaseBackup = nil
        availableBackups = []
        
        await scanBackups()
        logger.info("Rescan completed: \(self.availableBackups.count) backups found")
    }
    
    // MARK: - App Management
    
    /// Load and update app installation status
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
            }
            
            logger.info("Loaded \(self.apps.count) apps (\(self.userStore.customApps.count) custom)")
        }
        
        await loadAppsTask?.value
    }
    
    // MARK: - Icon Management
    
    /// Get icon for app config
    func getIcon(for app: AppConfig) -> NSImage {
        iconService.getIcon(for: app.bundleId, category: app.category)
    }
    
    /// Get icon for backup app info
    func getIcon(for backupApp: BackupAppInfo) -> NSImage {
        iconService.getIcon(for: backupApp.bundleId, category: backupApp.category)
    }
    
    // MARK: - Backup Management
    
    /// Scan for available backups
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
            
            if let currentBase = incrementalBaseBackup,
               !availableBackups.contains(currentBase)
            {
                incrementalBaseBackup = nil
            }
            
            if incrementalBaseBackup == nil, let firstBackup = availableBackups.first {
                incrementalBaseBackup = firstBackup
            }
            
            logger.info("Found \(self.availableBackups.count) backups")
        }
        
        await scanBackupsTask?.value
    }
    
    /// Select backup for restore operations
    func selectBackup(_ backup: BackupInfo) {
        selectedBackup = backup
    }
    
    /// Select base backup for incremental operations
    func selectIncrementalBase(_ backup: BackupInfo) {
        incrementalBaseBackup = backup
    }
    
    // MARK: - Selection Management
    
    /// Toggle app selection state
    func toggleSelection(for app: AppConfig) {
        if let index = apps.firstIndex(where: { $0.id == app.id }) {
            apps[index].isSelected.toggle()
        }
    }
    
    /// Select all installed apps
    func selectAll() {
        apps = apps.map { app in
            var updated = app
            if updated.isInstalled {
                updated.isSelected = true
            }
            return updated
        }
    }
    
    /// Deselect all apps
    func deselectAll() {
        apps = apps.map { app in
            var updated = app
            updated.isSelected = false
            return updated
        }
    }
    
    /// Toggle restore app selection
    func toggleRestoreSelection(for app: BackupAppInfo) {
        guard let currentBackup = selectedBackup,
              let backupIndex = availableBackups.firstIndex(where: { $0.id == currentBackup.id }),
              let appIndex = availableBackups[backupIndex].apps.firstIndex(where: { $0.id == app.id })
        else { return }
        
        availableBackups[backupIndex].apps[appIndex].isSelected.toggle()
        selectedBackup = availableBackups[backupIndex]
    }
    
    // MARK: - Operations
    
    /// Start backup operation
    func performBackup() {
        Task {
            await performBackupAsync()
        }
    }
    
    /// Execute backup with progress tracking
    private func performBackupAsync() async {
        let startTime = Date()
        isProcessing = true
        currentProgress = 0.0
        statusMessage = NSLocalizedString("Backup_Starting", comment: "")
        statusMessageHistory = [statusMessage]
        
        let baseBackup = isIncrementalMode ? incrementalBaseBackup : nil
        
        let result = await backupService.performBackup(
            apps: apps,
            incrementalBase: baseBackup,
            onProgress: { @MainActor update in
                self.currentProgress = update.fraction
                if let message = update.message {
                    self.statusMessage = message
                    self.addToMessageHistory(message)
                }
            },
        )
        
        let elapsed = Date().timeIntervalSince(startTime)
        let minDuration = 1.3
        if elapsed < minDuration {
            try? await Task.sleep(for: .seconds(minDuration - elapsed))
        }
        
        currentProgress = 1.0
        statusMessage = result.statusMessage
        addToMessageHistory(result.statusMessage)
        
        try? await Task.sleep(for: .seconds(0.5))
        await scanBackups()
        
        try? await Task.sleep(for: .seconds(0.2))
        isProcessing = false
        currentProgress = 0.0
        statusMessageHistory = []
    }
    
    /// Start restore operation
    func performRestore() {
        guard let backup = selectedBackup else {
            logger.error("No backup selected for restore")
            return
        }
        
        Task {
            await performRestoreAsync(backup: backup)
        }
    }
    
    /// Execute restore with progress tracking
    private func performRestoreAsync(backup: BackupInfo) async {
        let startTime = Date()
        isProcessing = true
        currentProgress = 0.0
        statusMessage = NSLocalizedString("Restore_Starting", comment: "")
        statusMessageHistory = [statusMessage]
        
        let result = await restoreService.performRestore(
            backup: backup,
            onProgress: { @MainActor update in
                self.currentProgress = update.fraction
                if let message = update.message {
                    self.statusMessage = message
                    self.addToMessageHistory(message)
                }
            },
        )
        
        let elapsed = Date().timeIntervalSince(startTime)
        let minDuration = 1.3
        if elapsed < minDuration {
            try? await Task.sleep(for: .seconds(minDuration - elapsed))
        }
        
        currentProgress = 1.0
        statusMessage = result.statusMessage
        addToMessageHistory(result.statusMessage)
        
        try? await Task.sleep(for: .seconds(0.5))
        await loadApps()
        
        try? await Task.sleep(for: .seconds(0.2))
        isProcessing = false
        currentProgress = 0.0
        statusMessageHistory = []
    }
    
    /// Scan apps in specific backup directory
    func scanAppsInBackup(at path: String) async -> [BackupAppInfo] {
        await backupService.scanAppsInBackup(at: path)
    }
    
    // MARK: - Message History
    
    /// Add message to status history with limit
    private func addToMessageHistory(_ message: String) {
        statusMessageHistory.append(message)
        if statusMessageHistory.count > 3 {
            statusMessageHistory.removeFirst()
        }
    }
}
