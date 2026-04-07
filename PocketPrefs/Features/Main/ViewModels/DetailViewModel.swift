//
//  DetailViewModel.swift
//  PocketPrefs
//
//  Detail view state and operation management.
//

import Foundation
import Observation
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
    @ObservationIgnored private var isObservingCoordinator = false

    init(mainViewModel: MainViewModel) {
        self.mainViewModel = mainViewModel
        refreshFromCoordinator()
        startCoordinatorObservation()
    }

    private var coordinator: MainCoordinator? {
        mainViewModel?.coordinator
    }

    private func startCoordinatorObservation() {
        guard !isObservingCoordinator else { return }
        isObservingCoordinator = true
        observeCoordinatorState()
    }

    private func observeCoordinatorState() {
        withObservationTracking {
            _ = coordinator?.currentApps
            _ = coordinator?.selectedBackup
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refreshFromCoordinator()
                self.observeCoordinatorState()
            }
        }
    }

    private func refreshFromCoordinator() {
        let apps = coordinator?.currentApps ?? []
        hasValidBackupSelection = apps.contains { $0.isSelected && $0.isInstalled }

        let backup = coordinator?.selectedBackup
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
