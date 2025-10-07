//
//  RestoreListViewModel.swift
//  PocketPrefs
//
//  Restore backup list state management
//

import Foundation
import os.log
import SwiftUI

@MainActor
final class RestoreListViewModel: ObservableObject {
    // MARK: - Published State
    
    @Published var selectedBackup: BackupInfo?
    @Published var availableBackups: [BackupInfo] = []
    @Published var searchText = ""
    @Published var filteredApps: [BackupAppInfo] = []
    @Published var isRefreshing = false
    @Published var cachedAllSelected = false
    @Published var cachedSelectedCount = 0
    @Published var cachedTotalCount = 0
    
    // MARK: - Dependencies
    
    private weak var coordinator: MainCoordinator?
    private let logger = Logger(subsystem: "com.pocketprefs", category: "RestoreListViewModel")
    
    private var eventTask: Task<Void, Never>?
    private var searchDebounceTask: Task<Void, Never>?
    
    private static let searchDebounceDelay: Duration = .milliseconds(300)
    
    // MARK: - Initialization
    
    init(coordinator: MainCoordinator) {
        self.coordinator = coordinator
        subscribeToEvents()
    }
    
    deinit {
        eventTask?.cancel()
        searchDebounceTask?.cancel()
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
                case .backupsUpdated(let backups):
                    self.handleBackupsUpdate(backups)
                case .selectedBackupUpdated(let backup):
                    self.handleSelectedBackupUpdate(backup)
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Public Interface
    
    /// Initialize view state
    func onAppear() {
        guard let coordinator else { return }
        availableBackups = coordinator.currentBackups
        selectedBackup = coordinator.currentSelectedBackup
        updateFilteredApps()
        updateCachedState()
    }
    
    /// Handle search text changes with debouncing
    func handleSearchChange(_ newValue: String) {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            try? await Task.sleep(for: Self.searchDebounceDelay)
            guard !Task.isCancelled else { return }
            updateFilteredApps()
            updateCachedState()
        }
    }
    
    /// Toggle selection for specific app in backup
    func toggleSelection(for app: BackupAppInfo) {
        coordinator?.toggleRestoreSelection(for: app)
    }
    
    /// Toggle selection for all filtered apps
    func toggleSelectAll() {
        guard let coordinator else { return }
        
        if cachedAllSelected {
            coordinator.deselectAllRestoreApps()
        } else {
            coordinator.selectAllRestoreApps()
        }
    }
    
    /// Select backup for restore
    func selectBackup(_ backup: BackupInfo) {
        coordinator?.selectBackup(backup)
    }
    
    /// Refresh available backups
    func refreshBackups() async {
        guard let coordinator else { return }
        isRefreshing = true
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        await coordinator.scanBackups()
        
        isRefreshing = false
    }
    
    // MARK: - Event Handlers

    private var lastBackupsUpdate: Date?
    private var lastSelectedBackupUpdate: Date?

    private func handleBackupsUpdate(_ backups: [BackupInfo]) {
        if let last = lastBackupsUpdate, Date().timeIntervalSince(last) < 0.1 {
            return
        }
        lastBackupsUpdate = Date()
        
        availableBackups = backups
        
        // Update selectedBackup from new backups array
        if let current = selectedBackup,
           let updated = backups.first(where: { $0.id == current.id })
        {
            selectedBackup = updated
        } else if let current = selectedBackup, !backups.contains(where: { $0.id == current.id }) {
            selectedBackup = backups.first
        }
        
        updateFilteredApps()
        updateCachedState()
    }

    private func handleSelectedBackupUpdate(_ backup: BackupInfo?) {
        if let last = lastSelectedBackupUpdate, Date().timeIntervalSince(last) < 0.1 {
            return
        }
        lastSelectedBackupUpdate = Date()
        
        if let backup {
            // Sync with availableBackups to get latest state
            if let updated = availableBackups.first(where: { $0.id == backup.id }) {
                selectedBackup = updated
            } else {
                selectedBackup = backup
            }
        } else {
            selectedBackup = backup
        }
        
        updateFilteredApps()
        updateCachedState()
    }
    
    // MARK: - Private Implementation
    
    private func updateFilteredApps() {
        guard let backup = selectedBackup else {
            filteredApps = []
            return
        }
        
        if searchText.isEmpty {
            filteredApps = backup.apps
        } else {
            filteredApps = backup.apps.filter { app in
                app.name.localizedCaseInsensitiveContains(searchText) ||
                    app.bundleId.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func updateCachedState() {
        guard let backup = selectedBackup else {
            cachedAllSelected = false
            cachedSelectedCount = 0
            cachedTotalCount = 0
            return
        }
        
        let filtered = backup.apps.filter {
            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
        }
        
        cachedTotalCount = filtered.count
        cachedSelectedCount = filtered.count(where: { $0.isSelected })
        cachedAllSelected = !filtered.isEmpty && filtered.allSatisfy(\.isSelected)
    }
}
