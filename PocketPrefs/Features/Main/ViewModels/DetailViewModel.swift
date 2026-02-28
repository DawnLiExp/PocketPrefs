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
    // MARK: - State

    private(set) var apps: [AppConfig] = []
    private(set) var selectedBackup: BackupInfo?

    // MARK: - Dependencies

    private weak var mainViewModel: MainViewModel?
    private let logger = Logger(subsystem: "com.pocketprefs", category: "DetailViewModel")

    @ObservationIgnored private var eventTask: Task<Void, Never>?

    // MARK: - Initialization

    init(mainViewModel: MainViewModel) {
        self.mainViewModel = mainViewModel
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
            let eventStream = CoordinatorEventPublisher.shared.subscribe()

            for await event in eventStream {
                guard !Task.isCancelled else { break }

                switch event {
                case .appsUpdated(let updatedApps):
                    self.apps = updatedApps
                case .selectedBackupUpdated(let backup):
                    self.selectedBackup = backup
                case .backupsUpdated:
                    // @Observable tracks selectedBackup automatically;
                    // touch it to propagate any indirect backup state changes
                    self.selectedBackup = self.selectedBackup
                default:
                    break
                }
            }
        }
    }

    // MARK: - Computed Properties

    /// Check if valid backup selection exists
    var hasValidBackupSelection: Bool {
        !apps.filter { $0.isSelected && $0.isInstalled }.isEmpty
    }

    /// Count selected apps in current backup
    var selectedRestoreAppsCount: Int {
        selectedBackup?.apps.count(where: { $0.isSelected }) ?? 0
    }

    /// Count uninstalled selected apps in current backup
    var uninstalledSelectedCount: Int {
        selectedBackup?.apps.count(where: { !$0.isCurrentlyInstalled && $0.isSelected }) ?? 0
    }

    /// Check if current backup has selected apps for restore
    var hasSelectedRestoreApps: Bool {
        selectedRestoreAppsCount > 0
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
