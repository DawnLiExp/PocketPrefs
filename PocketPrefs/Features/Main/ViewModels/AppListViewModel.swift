//
//  AppListViewModel.swift
//  PocketPrefs
//
//  Backup app list state management
//

import Foundation
import os.log
import SwiftUI

@MainActor
final class AppListViewModel: ObservableObject {
    // MARK: - Published State
    
    @Published var apps: [AppConfig] = []
    @Published var searchText = ""
    @Published var filteredApps: [AppConfig] = []
    @Published var cachedAllSelected = false
    @Published var installedCount = 0
    
    // MARK: - Dependencies
    
    private weak var coordinator: MainCoordinator?
    private let logger = Logger(subsystem: "com.pocketprefs", category: "AppListViewModel")
    
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
                
                if case .appsUpdated(let updatedApps) = event {
                    self.handleAppsUpdate(updatedApps)
                }
            }
        }
    }
    
    // MARK: - Public Interface
    
    /// Initialize view state
    func onAppear() {
        guard let coordinator else { return }
        apps = coordinator.currentApps
        updateFilteredApps(source: apps, searchTerm: searchText)
        updateCachedState(apps: apps)
    }
    
    /// Handle search text changes with debouncing
    func handleSearchChange(_ newValue: String) {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            try? await Task.sleep(for: Self.searchDebounceDelay)
            guard !Task.isCancelled else { return }
            updateFilteredApps(source: apps, searchTerm: newValue)
        }
    }
    
    /// Toggle selection for specific app
    func toggleSelection(for app: AppConfig) {
        coordinator?.toggleSelection(for: app)
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
    
    // MARK: - Event Handlers
    
    private func handleAppsUpdate(_ updatedApps: [AppConfig]) {
        apps = updatedApps
        updateFilteredApps(source: apps, searchTerm: searchText)
        updateCachedState(apps: apps)
    }
    
    // MARK: - Private Implementation
    
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
    
    private func updateCachedState(apps: [AppConfig]) {
        let installedApps = apps.filter(\.isInstalled)
        installedCount = installedApps.count
        cachedAllSelected = !installedApps.isEmpty && installedApps.allSatisfy(\.isSelected)
    }
}
