//
//  DetailViewModel.swift
//  PocketPrefs
//
//  Detail view state and operation management.
//

import Foundation
import os.log
import SwiftUI

@MainActor
@Observable
final class DetailViewModel {
    // MARK: - Cached Backup Selection State

    var hasValidBackupSelection = false

    // MARK: - Cached Restore Selection State

    var selectedBackup: BackupInfo?
    var selectedRestoreAppsCount = 0
    var uninstalledSelectedCount = 0
    var hasSelectedRestoreApps = false

    // MARK: - Dependencies

    private weak var mainViewModel: MainViewModel?
    @ObservationIgnored private var eventTask: Task<Void, Never>?

    init(mainViewModel: MainViewModel) {
        self.mainViewModel = mainViewModel
        syncFromCoordinator(mainViewModel.coordinator)
        subscribeToEvents()
    }

    deinit {
        eventTask?.cancel()
    }

    private func subscribeToEvents() {
        eventTask?.cancel()
        eventTask = Task { [weak self] in
            guard let self else { return }
            let stream = CoordinatorEventPublisher.shared.subscribe()

            for await event in stream {
                guard !Task.isCancelled else { break }
                self.handleCoordinatorEvent(event)
            }
        }
    }

    private func handleCoordinatorEvent(_ event: CoordinatorEvent) {
        switch event {
        case .appsUpdated(let apps):
            hasValidBackupSelection = apps.contains { $0.isSelected && $0.isInstalled }

        case .selectedBackupUpdated(let backup):
            selectedBackup = backup
            updateRestoreState(from: backup)

        case .backupsUpdated:
            break

        case .operationStarted, .operationCompleted:
            break
        }
    }

    private func syncFromCoordinator(_ coordinator: MainCoordinator) {
        let apps = coordinator.currentApps
        hasValidBackupSelection = apps.contains { $0.isSelected && $0.isInstalled }

        let backup = coordinator.currentSelectedBackup
        selectedBackup = backup
        updateRestoreState(from: backup)
    }

    private func updateRestoreState(from backup: BackupInfo?) {
        guard let backup else {
            selectedRestoreAppsCount = 0
            uninstalledSelectedCount = 0
            hasSelectedRestoreApps = false
            return
        }

        let selectedApps = backup.apps.filter(\.isSelected)
        selectedRestoreAppsCount = selectedApps.count
        uninstalledSelectedCount = selectedApps.count(where: { !$0.isCurrentlyInstalled })
        hasSelectedRestoreApps = !selectedApps.isEmpty
    }

    // MARK: - Actions

    /// Request backup operation
    func performBackup() {
        mainViewModel?.requestBackup()
    }

    /// Request restore operation
    func performRestore() {
        mainViewModel?.requestRestore()
    }
}
