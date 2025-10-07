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
final class DetailViewModel: ObservableObject {
    // MARK: - Published State
    
    @Published private(set) var apps: [AppConfig] = []
    @Published private(set) var selectedBackup: BackupInfo?
    
    // MARK: - Dependencies
    
    private weak var mainViewModel: MainViewModel?
    private let logger = Logger(subsystem: "com.pocketprefs", category: "DetailViewModel")
    
    private var eventTask: Task<Void, Never>?
    
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
    
    /// Request backup operation
    func performBackup() {
        mainViewModel?.requestBackup()
    }
    
    /// Request restore operation
    func performRestore() {
        mainViewModel?.requestRestore()
    }
}
