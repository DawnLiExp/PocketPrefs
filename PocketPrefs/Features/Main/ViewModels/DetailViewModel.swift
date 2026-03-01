//
//  DetailViewModel.swift
//  PocketPrefs
//
//  Detail view state and operation management
//

import Foundation
import os.log
import SwiftUI

@MainActor
@Observable
final class DetailViewModel {
    // MARK: - Cached Backup Selection State
    // Stored properties so @Observable correctly tracks changes for view re-renders.
    // Derived from coordinator state via direct event subscription.

    var hasValidBackupSelection: Bool = false

    // MARK: - Cached Restore Selection State

    var selectedBackup: BackupInfo? = nil
    var selectedRestoreAppsCount: Int = 0
    var uninstalledSelectedCount: Int = 0
    var hasSelectedRestoreApps: Bool = false

    // MARK: - Dependencies

    private weak var mainViewModel: MainViewModel?
    private let logger = Logger(subsystem: "com.pocketprefs", category: "DetailViewModel")

    @ObservationIgnored private var eventTask: Task<Void, Never>?

    // MARK: - Initialization

    init(mainViewModel: MainViewModel) {
        self.mainViewModel = mainViewModel
        // Sync initial state from coordinator
        syncFromCoordinator(mainViewModel.coordinator)
        subscribeToEvents()
    }

    deinit {
        eventTask?.cancel()
    }

    // MARK: - Event Subscription

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
            // selectedBackup is kept in sync via selectedBackupUpdated
            break

        case .operationStarted, .operationCompleted:
            break
        }
    }

    // MARK: - Private Helpers

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

        let selected = backup.apps.filter(\.isSelected)
        selectedRestoreAppsCount = selected.count
        uninstalledSelectedCount = selected.filter { !$0.isCurrentlyInstalled }.count
        hasSelectedRestoreApps = !selected.isEmpty
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
