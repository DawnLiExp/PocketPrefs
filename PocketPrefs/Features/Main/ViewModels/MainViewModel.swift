//
//  MainViewModel.swift
//  PocketPrefs
//
//  Global UI state management and operation coordination
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class MainViewModel {
    // MARK: - Operation State
    
    private(set) var isProcessing = false
    private(set) var operationResult: OperationSummary?
    var statusMessage = ""
    var currentProgress: Double = 0.0
    var statusMessageHistory: [String] = []
    
    // MARK: - Incremental Backup State
    
    var isIncrementalMode = false
    @ObservationIgnored private var _incrementalBaseBackupId: String?

    var incrementalBaseBackup: BackupInfo? {
        if let id = _incrementalBaseBackupId,
           let matched = coordinator.currentBackups.first(where: { $0.id == id })
        {
            return matched
        }
        return coordinator.currentBackups.first
    }
    
    // MARK: - Dependencies
    
    private let coordinator: MainCoordinator
    typealias BackupOperation = @MainActor ([AppConfig], BackupInfo?, @escaping ProgressHandler) async -> BackupResult
    typealias RestoreOperation = @MainActor (BackupInfo, Bool, @escaping ProgressHandler) async -> RestoreResult
    @ObservationIgnored private let backupOperation: BackupOperation
    @ObservationIgnored private let restoreOperation: RestoreOperation
    @ObservationIgnored private let restoreBackupPreference: @MainActor () -> Bool
    @ObservationIgnored private var operationTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(
        coordinator: MainCoordinator,
        backupOperation: BackupOperation? = nil,
        restoreOperation: RestoreOperation? = nil,
        restoreBackupPreference: @escaping @MainActor () -> Bool = { PreferencesManager.shared.createBackupBeforeRestore }
    ) {
        self.coordinator = coordinator
        self.backupOperation = backupOperation ?? { apps, base, progress in
            await coordinator.performBackupOperation(apps: apps, incrementalBase: base, onProgress: progress)
        }
        self.restoreOperation = restoreOperation ?? { backup, createBackup, progress in
            await coordinator.performRestoreOperation(backup: backup, createBackupBeforeRestore: createBackup, onProgress: progress)
        }
        self.restoreBackupPreference = restoreBackupPreference
    }
    
    deinit {
        operationTask?.cancel()
    }
    
    // MARK: - Window-owned Operation

    private func startOperation(_ operation: @escaping @MainActor (@escaping ProgressHandler) async -> OperationSummary) {
        isProcessing = true
        currentProgress = 0
        statusMessage = ""
        statusMessageHistory = []
        operationTask = Task { [weak self] in
            let result = await operation { [weak self] update in
                self?.updateProgress(update)
            }
            guard !Task.isCancelled, let self else { return }
            self.operationResult = result
            self.isProcessing = false
            self.currentProgress = 0
            self.statusMessageHistory = []
            self.operationTask = nil
        }
    }

    // MARK: - State Updates
    
    private func updateProgress(_ update: ProgressUpdate) {
        currentProgress = update.fraction
        
        if let message = update.message {
            statusMessage = message
            addToMessageHistory(message)
        }
    }
    
    private func addToMessageHistory(_ message: String) {
        statusMessageHistory.append(message)
        if statusMessageHistory.count > 3 {
            statusMessageHistory.removeFirst()
        }
    }
    
    // MARK: - Public Interface
    
    /// Select base backup for incremental operations
    func selectIncrementalBase(_ backup: BackupInfo) {
        _incrementalBaseBackupId = backup.id
        coordinator.selectIncrementalBase(backup)
    }
    
    /// Request backup operation
    func requestBackup() {
        guard !isProcessing, operationResult == nil else { return }
        let apps = coordinator.currentApps
        let base = isIncrementalMode ? incrementalBaseBackup : nil
        startOperation { [backupOperation] progress in
            OperationSummary(backup: await backupOperation(apps, base, progress))
        }
    }
    
    /// Request restore operation
    func requestRestore() {
        guard !isProcessing, operationResult == nil else { return }
        guard let backup = coordinator.currentSelectedBackup else {
            var summary = OperationSummary(restore: RestoreResult(successCount: 0, failedApps: [], totalProcessed: 0))
            summary.notice = String(localized: "Operation_Result_Missing_Backup")
            operationResult = summary
            return
        }
        let createBackup = restoreBackupPreference()
        startOperation { [restoreOperation] progress in
            OperationSummary(restore: await restoreOperation(backup, createBackup, progress))
        }
    }

    func dismissOperationResult() {
        guard !isProcessing else { return }
        operationResult = nil
    }

    func waitForOperation() async {
        await operationTask?.value
    }
}
