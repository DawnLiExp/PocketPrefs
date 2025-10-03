//
//  BackupManager.swift
//  PocketPrefs
//
//  Main backup manager with structured concurrency and AsyncStream events
//

import Foundation
import os.log
import SwiftUI

@MainActor
final class BackupManager: ObservableObject {
    @Published var apps: [AppConfig] = []
    @Published var isProcessing = false
    @Published var statusMessage = ""
    @Published var currentProgress: Double = 0.0
    @Published var statusMessageHistory: [String] = [] // For scrolling display
    
    @Published var availableBackups: [BackupInfo] = []
    @Published var selectedBackup: BackupInfo?
    
    @Published var isIncrementalMode = false
    @Published var incrementalBaseBackup: BackupInfo?
    
    private let logger = Logger(subsystem: "com.pocketprefs", category: "BackupManager")
    private let iconService = IconService.shared
    private let backupService = BackupService()
    private let restoreService = RestoreService()
    private let fileOps = FileOperationService.shared
    private let userStore = UserConfigStore.shared
    
    private var storeEventTask: Task<Void, Never>?
    private var prefsEventTask: Task<Void, Never>?
    private var iconEventTask: Task<Void, Never>?
    
    private var loadAppsTask: Task<Void, Never>?
    private var scanBackupsTask: Task<Void, Never>?
    
    private enum DebounceConfig {
        static let storeEventDelay = 0.3
        static let iconEventDelay = 0.5
    }
    
    init() {
        Task {
            await loadApps()
            await scanBackups()
        }
        
        subscribeToStoreEvents()
        subscribeToPreferencesEvents()
        subscribeToIconEvents()
    }
    
    deinit {
        storeEventTask?.cancel()
        prefsEventTask?.cancel()
        iconEventTask?.cancel()
        loadAppsTask?.cancel()
        scanBackupsTask?.cancel()
    }
    
    // MARK: - Event Subscriptions
    
    private func subscribeToStoreEvents() {
        storeEventTask?.cancel()
        storeEventTask = Task { [weak self] in
            guard let self else { return }
            
            var pendingReload = false
            
            for await event in userStore.events {
                guard !Task.isCancelled else { break }
                
                switch event {
                case .appAdded, .appUpdated, .appsRemoved, .batchUpdated, .appsChanged:
                    if !pendingReload {
                        pendingReload = true
                        
                        try? await Task.sleep(for: .seconds(DebounceConfig.storeEventDelay))
                        
                        guard !Task.isCancelled else { break }
                        
                        await self.loadApps()
                        pendingReload = false
                    }
                }
            }
        }
    }
    
    private func subscribeToPreferencesEvents() {
        prefsEventTask?.cancel()
        prefsEventTask = Task { [weak self] in
            guard let self else { return }
            
            for await event in PreferencesManager.shared.events {
                guard !Task.isCancelled else { break }
                
                if case .directoryChanged(let path) = event {
                    logger.info("Directory changed event received: \(path)")
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
                
                try? await Task.sleep(for: .seconds(DebounceConfig.iconEventDelay))
                
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
        logger.info("Handling directory change, rescanning...")
        
        selectedBackup = nil
        incrementalBaseBackup = nil
        availableBackups = []
        
        await scanBackups()
        
        logger.info("Rescan completed: \(self.availableBackups.count) backups found")
    }
    
    // MARK: - App Loading
    
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
    
    func manualRefresh() async {
        logger.info("Manual refresh triggered in BackupManager")
        
        // Cancel pending event-triggered reloads to clear debounce state
        storeEventTask?.cancel()
        loadAppsTask?.cancel()
        
        // Restart event subscription with clean state
        subscribeToStoreEvents()
        
        // Load latest data immediately
        await loadApps()
        objectWillChange.send()
        
        logger.info("Manual refresh completed")
    }
    
    // MARK: - Icon Management
    
    func getIcon(for app: AppConfig) -> NSImage {
        iconService.getIcon(for: app.bundleId, category: app.category)
    }
    
    func getIcon(for backupApp: BackupAppInfo) -> NSImage {
        iconService.getIcon(for: backupApp.bundleId, category: backupApp.category)
    }
    
    // MARK: - Backup Operations
    
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
            
            if selectedBackup == nil,
               let firstBackup = availableBackups.first
            {
                selectBackup(firstBackup)
            }
            
            if let currentBase = incrementalBaseBackup,
               !availableBackups.contains(currentBase)
            {
                incrementalBaseBackup = nil
            }
            
            if incrementalBaseBackup == nil,
               let firstBackup = availableBackups.first
            {
                incrementalBaseBackup = firstBackup
            }
            
            logger.info("Found \(self.availableBackups.count) backups")
        }
        
        await scanBackupsTask?.value
    }
    
    func selectBackup(_ backup: BackupInfo) {
        selectedBackup = backup
    }
    
    func selectIncrementalBase(_ backup: BackupInfo) {
        incrementalBaseBackup = backup
    }
    
    // MARK: - Selection Management
    
    func toggleSelection(for app: AppConfig) {
        if let index = apps.firstIndex(where: { $0.id == app.id }) {
            apps[index].isSelected.toggle()
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
    }
    
    func deselectAll() {
        apps = apps.map { app in
            var updated = app
            updated.isSelected = false
            return updated
        }
    }
    
    func toggleRestoreSelection(for app: BackupAppInfo) {
        guard let currentBackup = selectedBackup,
              let backupIndex = availableBackups.firstIndex(where: { $0.id == currentBackup.id }),
              let appIndex = availableBackups[backupIndex].apps.firstIndex(where: { $0.id == app.id })
        else { return }
        
        availableBackups[backupIndex].apps[appIndex].isSelected.toggle()
        selectedBackup = availableBackups[backupIndex]
    }
    
    // MARK: - Backup & Restore
    
    func performBackup() {
        Task {
            await performBackupAsync()
        }
    }
    
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
        
        // Ensure minimum operation duration for better UX (avoid "instant" completion)
        let elapsed = Date().timeIntervalSince(startTime)
        let minDuration = 1.3
        if elapsed < minDuration {
            try? await Task.sleep(for: .seconds(minDuration - elapsed))
        }
        
        currentProgress = 1.0
        statusMessage = result.statusMessage
        addToMessageHistory(result.statusMessage)
        
        // Pause at 100% for visual confirmation
        try? await Task.sleep(for: .seconds(0.5))
        await scanBackups()
        
        try? await Task.sleep(for: .seconds(0.2))
        isProcessing = false
        currentProgress = 0.0
        statusMessageHistory = []
    }
    
    func performRestore() {
        guard let backup = selectedBackup else {
            logger.error("No backup selected for restore")
            return
        }
        
        Task {
            await performRestoreAsync(backup: backup)
        }
    }
    
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
        
        // Ensure minimum operation duration for better UX
        let elapsed = Date().timeIntervalSince(startTime)
        let minDuration = 1.3
        if elapsed < minDuration {
            try? await Task.sleep(for: .seconds(minDuration - elapsed))
        }
        
        currentProgress = 1.0
        statusMessage = result.statusMessage
        addToMessageHistory(result.statusMessage)
        
        // Pause at 100% for visual confirmation
        try? await Task.sleep(for: .seconds(0.5))
        await loadApps()
        
        try? await Task.sleep(for: .seconds(0.2))
        isProcessing = false
        currentProgress = 0.0
        statusMessageHistory = []
    }
    
    func scanAppsInBackup(at path: String) async -> [BackupAppInfo] {
        await backupService.scanAppsInBackup(at: path)
    }
    
    // MARK: - Message History Management
    
    private func addToMessageHistory(_ message: String) {
        statusMessageHistory.append(message)
        if statusMessageHistory.count > 3 {
            statusMessageHistory.removeFirst()
        }
    }
}
