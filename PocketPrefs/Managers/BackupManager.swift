//
//  BackupManager.swift
//  PocketPrefs
//
//  Main backup manager coordinating all operations
//

@preconcurrency import Foundation
import os.log
import SwiftUI

@MainActor
final class BackupManager: ObservableObject {
    @Published var apps: [AppConfig] = []
    @Published var isProcessing = false
    @Published var statusMessage = ""
    @Published var currentProgress: Double = 0.0
    
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
    
    private var eventTask: Task<Void, Never>?
    private nonisolated(unsafe) var directoryChangeObserver: NSObjectProtocol?
    
    private enum ProgressConfig {
        static let targetProgress = 0.98
        static let duration = 3.0
        static let steps = 40
        static let completionPause = 0.5
        static let finalPause = 0.3
    }
    
    init() {
        Task {
            await loadApps()
            await scanBackups()
        }
        
        subscribeToEvents()
        observeDirectoryChanges()
    }
    
    deinit {
        eventTask?.cancel()
        if let observer = directoryChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Event Subscriptions
    
    private func subscribeToEvents() {
        eventTask?.cancel()
        eventTask = Task { [weak self] in
            guard let self else { return }
            
            for await event in userStore.events {
                guard !Task.isCancelled else { break }
                
                switch event {
                case .appAdded, .appUpdated, .appsRemoved, .batchUpdated:
                    await self.loadApps()
                case .appsChanged:
                    await self.loadApps()
                }
            }
        }
    }
    
    private func observeDirectoryChanges() {
        directoryChangeObserver = NotificationCenter.default.addObserver(
            forName: .backupDirectoryChanged,
            object: nil,
            queue: .main,
        ) { [weak self] notification in
            guard let self else { return }
            
            if let newPath = notification.userInfo?["newPath"] as? String {
                self.logger.info("Backup directory changed notification received: \(newPath)")
                
                Task { @MainActor in
                    await self.handleDirectoryChange()
                }
            }
        }
    }
    
    private func handleDirectoryChange() async {
        logger.info("Handling backup directory change, rescanning backups...")
        
        selectedBackup = nil
        incrementalBaseBackup = nil
        availableBackups = []
        
        await scanBackups()
        
        logger.info("Backup rescan completed: \(self.availableBackups.count) backups found")
    }
    
    // MARK: - App Loading
    
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
                if let index = updatedApps.firstIndex(where: { $0.id == appId }) {
                    updatedApps[index].isInstalled = isInstalled
                    updatedApps[index].isSelected = false
                }
            }
            
            self.apps = updatedApps
        }
        
        logger.info("Loaded \(self.apps.count) apps (including \(self.userStore.customApps.count) custom apps)")
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
        availableBackups = await backupService.scanBackups()
        
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
    
    // MARK: - Backup & Restore
    
    func performBackup() {
        Task {
            await performBackupAsync()
        }
    }
    
    private func performBackupAsync() async {
        isProcessing = true
        currentProgress = 0.0
        statusMessage = NSLocalizedString("Backup_Starting", comment: "")
        
        let baseBackup = isIncrementalMode ? incrementalBaseBackup : nil
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                await self?.monitorProgress(
                    targetProgress: ProgressConfig.targetProgress,
                    duration: ProgressConfig.duration,
                )
            }
            
            group.addTask { [weak self] in
                guard let self else { return }
                let result = await self.backupService.performBackup(
                    apps: self.apps,
                    incrementalBase: baseBackup,
                )
                
                await MainActor.run {
                    self.currentProgress = 1.0
                    self.statusMessage = result.statusMessage
                }
                
                try? await Task.sleep(for: .seconds(ProgressConfig.completionPause))
                await self.scanBackups()
            }
            
            await group.waitForAll()
        }
        
        try? await Task.sleep(for: .seconds(ProgressConfig.finalPause))
        isProcessing = false
        currentProgress = 0.0
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
        isProcessing = true
        currentProgress = 0.0
        statusMessage = NSLocalizedString("Restore_Starting", comment: "")
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                await self?.monitorProgress(
                    targetProgress: ProgressConfig.targetProgress,
                    duration: ProgressConfig.duration,
                )
            }
            
            group.addTask { [weak self] in
                guard let self else { return }
                let result = await self.restoreService.performRestore(backup: backup)
                
                await MainActor.run {
                    self.currentProgress = 1.0
                    self.statusMessage = result.statusMessage
                }
                
                try? await Task.sleep(for: .seconds(ProgressConfig.completionPause))
                await self.loadApps()
            }
            
            await group.waitForAll()
        }
        
        try? await Task.sleep(for: .seconds(ProgressConfig.finalPause))
        isProcessing = false
        currentProgress = 0.0
    }
    
    // MARK: - Progress Monitoring
    
    private func monitorProgress(targetProgress: Double, duration: TimeInterval) async {
        let steps = ProgressConfig.steps
        let stepDuration = duration / Double(steps)
        let progressIncrement = targetProgress / Double(steps)
        
        for step in 0 ..< steps {
            guard !Task.isCancelled else { break }
            
            let newProgress = Double(step + 1) * progressIncrement
            currentProgress = min(newProgress, targetProgress)
            
            try? await Task.sleep(for: .seconds(stepDuration))
        }
    }
    
    func scanAppsInBackup(at path: String) async -> [BackupAppInfo] {
        await backupService.scanAppsInBackup(at: path)
    }
}
