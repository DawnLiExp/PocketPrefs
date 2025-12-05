//
//  RestoreListViewModel.swift
//  PocketPrefs
//
//  Restore backup list state management with sorting
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
    @Published var currentSortOption: SortOption = .nameAscending
    
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
    func onSettingsClose() {
        guard let coordinator else { return }
        coordinator.deselectAllRestoreApps()
        availableBackups = coordinator.currentBackups
        selectedBackup = coordinator.currentSelectedBackup
        updateFilteredApps()
    }
        
    func handleSearchChange(_ newValue: String) {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            try? await Task.sleep(for: Self.searchDebounceDelay)
            guard !Task.isCancelled else { return }
            updateFilteredApps()
            updateCachedState()
        }
    }
    
    /// Set sort option
    func setSortOption(_ option: SortOption) {
        currentSortOption = option
        updateFilteredApps()
    }
    
    func toggleSelection(for app: BackupAppInfo) {
        coordinator?.toggleRestoreSelection(for: app)
    }
    
    func toggleSelectAll() {
        guard let coordinator else { return }
        
        if cachedAllSelected {
            coordinator.deselectAllRestoreApps()
        } else {
            coordinator.selectAllRestoreApps()
        }
    }
        
    func selectBackup(_ backup: BackupInfo) {
        coordinator?.selectBackup(backup)
    }
        
    func refreshBackups() async {
        guard let coordinator else { return }
        isRefreshing = true
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        await coordinator.scanBackups()
        
        isRefreshing = false
    }
    
    // MARK: - Event Handlers
    
    private func handleBackupsUpdate(_ backups: [BackupInfo]) {
        availableBackups = backups
        
        // Sync selectedBackup with updated data
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
        // Sync with availableBackups to get latest state
        if let backup {
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
        
    private func deselectAllRestoreApps() {
        guard let coordinator else { return }
        coordinator.deselectAllRestoreApps()
    }
    
    private func updateFilteredApps() {
        guard let backup = selectedBackup else {
            filteredApps = []
            return
        }
        
        let filtered: [BackupAppInfo] = if searchText.isEmpty {
            backup.apps
        } else {
            backup.apps.filter { app in
                app.name.localizedCaseInsensitiveContains(searchText) ||
                    app.bundleId.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply sorting
        filteredApps = currentSortOption.apply(to: filtered)
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
