//
//  AppListViewModel.swift
//  PocketPrefs
//
//  ViewModel for backup app list view
//

import Foundation
import SwiftUI

@MainActor
final class AppListViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var filteredApps: [AppConfig] = []
    @Published var cachedAllSelected = false
    @Published var installedCount = 0
    
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
    
    /// Initialize view state with app data
    func onAppear(apps: [AppConfig]) {
        filteredApps = apps
        updateCachedState(apps: apps)
    }
    
    /// Handle coordinator app changes
    func handleAppsChange(apps: [AppConfig]) {
        updateFilteredApps(source: apps, searchTerm: searchText)
        updateCachedState(apps: apps)
    }
    
    /// Handle search text changes with debouncing
    func handleSearchChange(_ newValue: String, apps: [AppConfig]) {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            try? await Task.sleep(for: Self.searchDebounceDelay)
            guard !Task.isCancelled else { return }
            updateFilteredApps(source: apps, searchTerm: newValue)
        }
    }
    
    /// Toggle all app selection state
    func toggleSelectAll() {
        guard let coordinator else { return }
        if cachedAllSelected {
            coordinator.deselectAll()
        } else {
            coordinator.selectAll()
        }
    }
    
    // MARK: - Private Implementation
    
    /// Update filtered apps based on search criteria
    private func updateFilteredApps(source: [AppConfig], searchTerm: String) {
        if searchTerm.isEmpty {
            filteredApps = source
        } else {
            filteredApps = source.filter { app in
                app.name.localizedCaseInsensitiveContains(searchTerm) ||
                    app.bundleId.localizedCaseInsensitiveContains(searchTerm)
            }
        }
    }
    
    /// Update cached state for UI optimization
    private func updateCachedState(apps: [AppConfig]) {
        let installedApps = apps.filter(\.isInstalled)
        installedCount = installedApps.count
        cachedAllSelected = !installedApps.isEmpty && installedApps.allSatisfy(\.isSelected)
    }
}
