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
    var incrementalBaseBackup: BackupInfo?
    
    // MARK: - Dependencies
    
    let coordinator: MainCoordinator
    @ObservationIgnored private let logger = Logger(subsystem: "com.pocketprefs", category: "MainViewModel")
    
    @ObservationIgnored private var coordinatorEventTask: Task<Void, Never>?
    @ObservationIgnored private var operationEventTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init() {
        self.coordinator = MainCoordinator()
        subscribeToCoordinatorEvents()
        subscribeToOperationEvents()
    }
    
    deinit {
        coordinatorEventTask?.cancel()
        operationEventTask?.cancel()
    }
    
    // MARK: - Event Subscriptions
    
    private func subscribeToCoordinatorEvents() {
        coordinatorEventTask?.cancel()
        coordinatorEventTask = Task { [weak self] in
            guard let self else { return }
            let eventStream = CoordinatorEventPublisher.shared.subscribe()
            
            for await event in eventStream {
                guard !Task.isCancelled else { break }
                await self.handleCoordinatorEvent(event)
            }
        }
    }
    
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
    
    private func handleCoordinatorEvent(_ event: CoordinatorEvent) async {
        switch event {
        case .appsUpdated:
            break
        case .backupsUpdated:
            handleBackupsUpdate()
        case .selectedBackupUpdated:
            break
        case .operationStarted:
            isProcessing = true
        case .operationCompleted:
            isProcessing = false
            currentProgress = 0.0
            statusMessageHistory = []
        }
    }
    
    private func handleOperationEvent(_ event: OperationEvent) async {
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
    
    private func handleBackupsUpdate() {
        let availableBackups = coordinator.currentBackups
        
        if let currentBase = incrementalBaseBackup,
           !availableBackups.contains(currentBase)
        {
            incrementalBaseBackup = nil
        }
        
        if incrementalBaseBackup == nil, let firstBackup = availableBackups.first {
            incrementalBaseBackup = firstBackup
        }
    }
    
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
        incrementalBaseBackup = backup
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
