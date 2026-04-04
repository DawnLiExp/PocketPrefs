//
//  DetailViewModel.swift
//  PocketPrefs
//
//  Detail view state and operation management
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class DetailViewModel {
    // MARK: - Dependencies

    private weak var mainViewModel: MainViewModel?

    // MARK: - Computed from Coordinator

    var hasValidBackupSelection: Bool {
        mainViewModel?.coordinator.apps.contains { $0.isSelected && $0.isInstalled } ?? false
    }

    var selectedBackup: BackupInfo? {
        mainViewModel?.coordinator.selectedBackup
    }

    var selectedRestoreAppsCount: Int {
        selectedBackup?.apps.count(where: { $0.isSelected }) ?? 0
    }

    var uninstalledSelectedCount: Int {
        selectedBackup?.apps.count(where: { $0.isSelected && !$0.isCurrentlyInstalled }) ?? 0
    }

    var hasSelectedRestoreApps: Bool {
        selectedRestoreAppsCount > 0
    }

    // MARK: - Initialization

    init(mainViewModel: MainViewModel) {
        self.mainViewModel = mainViewModel
    }

    // MARK: - Actions

    func performBackup() {
        guard let mainViewModel else { return }
        Task { await mainViewModel.executeBackup() }
    }

    func performRestore() {
        guard let mainViewModel else { return }
        Task { await mainViewModel.executeRestore() }
    }
}
