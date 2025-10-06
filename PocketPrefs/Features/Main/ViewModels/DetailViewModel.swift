//
//  DetailViewModel.swift
//  PocketPrefs
//
//  ViewModel for detail view (backup and restore modes)
//

import Foundation
import SwiftUI

@MainActor
final class DetailViewModel: ObservableObject {
    private weak var coordinator: MainCoordinator?
    
    init(coordinator: MainCoordinator) {
        self.coordinator = coordinator
    }
    
    // MARK: - Computed Properties
    
    /// Check if valid backup selection exists
    var hasValidBackupSelection: Bool {
        guard let coordinator else { return false }
        return !coordinator.apps.filter { $0.isSelected && $0.isInstalled }.isEmpty
    }
    
    /// Count selected apps in backup
    func selectedRestoreAppsCount(backup: BackupInfo?) -> Int {
        backup?.apps.count(where: { $0.isSelected }) ?? 0
    }
    
    /// Count uninstalled selected apps in backup
    func uninstalledSelectedCount(backup: BackupInfo?) -> Int {
        backup?.apps.count(where: { !$0.isCurrentlyInstalled && $0.isSelected }) ?? 0
    }
    
    /// Check if backup has selected apps for restore
    func hasSelectedRestoreApps(backup: BackupInfo?) -> Bool {
        selectedRestoreAppsCount(backup: backup) > 0
    }
    
    // MARK: - Actions
    
    /// Trigger backup operation
    func performBackup() {
        coordinator?.performBackup()
    }
    
    /// Trigger restore operation
    func performRestore() {
        coordinator?.performRestore()
    }
}
