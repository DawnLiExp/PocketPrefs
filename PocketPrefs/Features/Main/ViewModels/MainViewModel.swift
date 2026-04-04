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
    // MARK: - Operation UI State

    var statusMessage = ""
    var currentProgress: Double = 0.0
    var statusMessageHistory: [String] = []

    // MARK: - Incremental Backup State

    var isIncrementalMode = false
    var incrementalBaseBackupID: BackupInfo.ID?

    // MARK: - Dependencies

    let coordinator: MainCoordinator

    var incrementalBaseBackup: BackupInfo? {
        guard let incrementalBaseBackupID else { return nil }
        return coordinator.availableBackups.first(where: { $0.id == incrementalBaseBackupID })
    }

    // MARK: - Initialization

    init() {
        self.coordinator = MainCoordinator()
    }

    // MARK: - Execute Operations

    func executeBackup() async {
        guard !coordinator.isProcessing else { return }
        prepareOperationUI()
        await coordinator.performBackupOperation(
            incrementalBase: isIncrementalMode ? incrementalBaseBackup : nil,
            onProgress: { [weak self] update in
                await self?.updateProgress(update)
            },
        )
        resetOperationUI()
    }

    func executeRestore() async {
        guard !coordinator.isProcessing else { return }
        prepareOperationUI()
        await coordinator.performRestoreOperation(
            onProgress: { [weak self] update in
                await self?.updateProgress(update)
            },
        )
        resetOperationUI()
    }

    // MARK: - Incremental Base

    func selectIncrementalBase(_ backup: BackupInfo) {
        incrementalBaseBackupID = backup.id
    }

    func syncIncrementalBase() {
        let backups = coordinator.availableBackups

        if let currentID = incrementalBaseBackupID,
           !backups.contains(where: { $0.id == currentID })
        {
            incrementalBaseBackupID = nil
        }

        if incrementalBaseBackupID == nil {
            incrementalBaseBackupID = backups.first?.id
        }
    }

    // MARK: - Private Helpers

    private func prepareOperationUI() {
        currentProgress = 0
        statusMessage = ""
        statusMessageHistory = []
    }

    private func resetOperationUI() {
        currentProgress = 0
        statusMessage = ""
        statusMessageHistory = []
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
}
