//
//  DetailViewModel.swift
//  PocketPrefs
//
//  Detail view state and operation management.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class DetailViewModel {
    // MARK: - Derived Backup Selection State

    var hasValidBackupSelection: Bool {
        guard let coordinator else { return false }
        return coordinator.currentApps.contains { $0.isInstalled && $0.isSelected }
    }

    // MARK: - Derived Restore Selection State

    var selectedBackup: BackupInfo? {
        coordinator?.currentSelectedBackup
    }

    var selectedRestoreAppsCount: Int {
        selectedBackup?.apps.count(where: \.isSelected) ?? 0
    }

    var uninstalledSelectedCount: Int {
        selectedBackup?.apps.count(where: { $0.isSelected && !$0.isCurrentlyInstalled }) ?? 0
    }

    var hasSelectedRestoreApps: Bool {
        selectedRestoreAppsCount > 0
    }

    // MARK: - Dependencies

    private weak var coordinator: MainCoordinator?
    private weak var mainViewModel: MainViewModel?

    init(coordinator: MainCoordinator, mainViewModel: MainViewModel) {
        self.coordinator = coordinator
        self.mainViewModel = mainViewModel
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
