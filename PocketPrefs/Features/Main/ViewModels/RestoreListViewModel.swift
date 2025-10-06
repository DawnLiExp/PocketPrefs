//
//  RestoreListViewModel.swift
//  PocketPrefs
//
//  ViewModel for restore backup list view
//

import Foundation
import SwiftUI

@MainActor
final class RestoreListViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var filteredApps: [BackupAppInfo] = []
    @Published var isRefreshing = false
    @Published var cachedAllSelected = false
    @Published var cachedSelectedCount = 0
    @Published var cachedTotalCount = 0
    
    private weak var coordinator: MainCoordinator?
    private var searchDebounceTask: Task<Void, Never>?
    
    private static let searchDebounceDelay: Duration = .milliseconds(300)
    
    init(coordinator: MainCoordinator) {
        self.coordinator = coordinator
    }
    
    deinit {
        searchDebounceTask?.cancel()
    }
    
    // MARK: - Public Interface
    
    /// Initialize view state with backup data
    func onAppear(backup: BackupInfo?) {
        updateFilteredApps(backup: backup)
        updateCachedState(backup: backup)
    }
    
    /// Handle backup selection change
    func handleBackupChange(backup: BackupInfo?) {
        searchDebounceTask?.cancel()
        updateFilteredApps(backup: backup)
        updateCachedState(backup: backup)
    }
    
    /// Handle search text changes with debouncing
    func handleSearchChange(_ newValue: String, backup: BackupInfo?) {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            try? await Task.sleep(for: Self.searchDebounceDelay)
            guard !Task.isCancelled else { return }
            updateFilteredApps(backup: backup)
            updateCachedState(backup: backup)
        }
    }
    
    /// Toggle selection for all filtered apps in backup
    func toggleSelectAll(backup: BackupInfo?) {
        guard let coordinator, let backup else { return }
        
        let filtered = backup.apps.filter {
            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
        }
        
        for app in filtered {
            if cachedAllSelected != app.isSelected {
                coordinator.toggleRestoreSelection(for: app)
            }
        }
    }
    
    /// Refresh available backups
    func refreshBackups() async {
        guard let coordinator else { return }
        isRefreshing = true
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        await coordinator.scanBackups()
        
        isRefreshing = false
    }
    
    // MARK: - Private Implementation
    
    /// Update filtered apps based on search criteria
    private func updateFilteredApps(backup: BackupInfo?) {
        guard let backup else {
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
    
    /// Update cached state for UI optimization
    private func updateCachedState(backup: BackupInfo?) {
        guard let backup else {
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
