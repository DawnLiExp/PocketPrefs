//
//  MainViewModel.swift
//  PocketPrefs
//
//  Global UI state management and operation coordination
//

import Foundation
import os.log
import SwiftUI

@MainActor
@Observable
final class MainViewModel {
    // MARK: - Operation State
    
    var isProcessing = false
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
    
    let coordinator: MainCoordinator
    @ObservationIgnored private let logger = Logger(subsystem: "com.me2.PocketPrefs", category: "MainViewModel")
    
    @ObservationIgnored private var operationEventTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init() {
        self.coordinator = MainCoordinator()
        subscribeToOperationEvents()
    }
    
    deinit {
        operationEventTask?.cancel()
    }
    
    // MARK: - Event Subscriptions
    
    private func subscribeToOperationEvents() {
        operationEventTask?.cancel()
        operationEventTask = Task { [weak self] in
            guard let self else { return }
            let eventStream = OperationEventPublisher.shared.subscribe()
            
            for await event in eventStream {
                guard !Task.isCancelled else { break }
                await self.handleOperationEvent(event)
            }
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleOperationEvent(_ event: OperationEvent) async {
        isProcessing = true
        defer {
            isProcessing = false
            currentProgress = 0.0
            statusMessageHistory = []
        }

        switch event {
        case .performBackup:
            await coordinator.performBackupOperation(
                incrementalBase: isIncrementalMode ? incrementalBaseBackup : nil,
                onProgress: { [weak self] update in
                    await self?.updateProgress(update)
                },
            )
        case .performRestore:
            await coordinator.performRestoreOperation(
                onProgress: { [weak self] update in
                    await self?.updateProgress(update)
                },
            )
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
        OperationEventPublisher.shared.publish(.performBackup)
    }
    
    /// Request restore operation
    func requestRestore() {
        OperationEventPublisher.shared.publish(.performRestore)
    }
}
