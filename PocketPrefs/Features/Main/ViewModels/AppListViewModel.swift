//
//  AppListViewModel.swift
//  PocketPrefs
//
//  Backup app list state management with sorting and persistence
//

import Foundation
import os.log
import SwiftUI

@MainActor
@Observable
final class AppListViewModel {
    // MARK: - State

    var apps: [AppConfig] = []
    var searchText = ""
    var filteredApps: [AppConfig] = []
    var cachedAllSelected = false
    var cachedSelectedCount = 0
    var installedCount = 0

    // MARK: - Persistent Sort Option

    @ObservationIgnored
    @AppStorage("backupSortOption") private var sortOptionRawValue: String = SortOption.nameAscending.rawValue

    var currentSortOption: SortOption {
        get { SortOption(rawValue: sortOptionRawValue) ?? .nameAscending }
        set {
            sortOptionRawValue = newValue.rawValue
            updateFilteredApps(source: apps, searchTerm: searchText)
        }
    }

    // MARK: - Dependencies

    private weak var coordinator: MainCoordinator?
    private let logger = Logger(subsystem: "com.pocketprefs", category: "AppListViewModel")

    @ObservationIgnored private var eventTask: Task<Void, Never>?
    @ObservationIgnored private var searchDebounceTask: Task<Void, Never>?

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

    /// Set sort option
    func setSortOption(_ option: SortOption) {
        currentSortOption = option
        updateFilteredApps(source: apps, searchTerm: searchText)
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

    @ObservationIgnored private var lastAppsUpdate: Date?

    private func handleAppsUpdate(_ updatedApps: [AppConfig]) {
        if let last = lastAppsUpdate, Date().timeIntervalSince(last) < 0.1 {
            return
        }
        lastAppsUpdate = Date()
        apps = updatedApps
        updateFilteredApps(source: apps, searchTerm: searchText)
        updateCachedState(apps: apps)
    }

    // MARK: - Private Implementation

    private func updateFilteredApps(source: [AppConfig], searchTerm: String) {
        let filtered: [AppConfig] = if searchTerm.isEmpty {
            source
        } else {
            source.filter { app in
                app.name.localizedCaseInsensitiveContains(searchTerm) ||
                    app.bundleId.localizedCaseInsensitiveContains(searchTerm)
            }
        }

        filteredApps = currentSortOption.apply(to: filtered)
    }

    private func updateCachedState(apps: [AppConfig]) {
        let installedApps = apps.filter(\.isInstalled)
        installedCount = installedApps.count
        cachedAllSelected = !installedApps.isEmpty && installedApps.allSatisfy(\.isSelected)
        cachedSelectedCount = apps.count(where: { $0.isSelected })
    }
}
