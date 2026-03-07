//
//  RestoreListViewModel.swift
//  PocketPrefs
//
//  Restore backup list state management with sorting and persistence
//

import Foundation
import os.log
import SwiftUI

@MainActor
@Observable
final class RestoreListViewModel {
    // MARK: - State

    var selectedBackup: BackupInfo?
    var availableBackups: [BackupInfo] = []
    var searchText = ""
    var filteredApps: [BackupAppInfo] = []
    var isRefreshing = false
    var cachedAllSelected = false
    var cachedSelectedCount = 0
    var cachedTotalCount = 0

    // MARK: - Persistent Sort Option

    /// Observable stored property — @Observable macro tracks this for UI re-renders.
    /// didSet syncs the new value to UserDefaults via @AppStorage.
    var currentSortOption: SortOption = .nameAscending {
        didSet {
            guard oldValue != currentSortOption else { return }
            guard supportedSortOptions.contains(currentSortOption) else {
                currentSortOption = oldValue
                return
            }
            sortOptionRawValue = currentSortOption.rawValue
            updateFilteredApps()
        }
    }

    /// Persistence only — @ObservationIgnored prevents macro conflicts with @AppStorage.
    @ObservationIgnored
    @AppStorage("restoreSortOption") private var sortOptionRawValue: String = SortOption.nameAscending.rawValue

    // MARK: - Public Properties

    /// Define available sort options for restore list (exclude date added)
    var supportedSortOptions: [SortOption] {
        [.nameAscending, .nameDescending]
    }

    // MARK: - Dependencies

    private weak var coordinator: MainCoordinator?
    private let logger = Logger(subsystem: "com.pocketprefs", category: "RestoreListViewModel")

    @ObservationIgnored private var eventTask: Task<Void, Never>?
    @ObservationIgnored private var searchDebounceTask: Task<Void, Never>?

    private static let searchDebounceDelay: Duration = .milliseconds(300)

    // MARK: - Initialization

    init(coordinator: MainCoordinator) {
        self.coordinator = coordinator
        // Restore persisted sort option without triggering didSet
        let saved = UserDefaults.standard.string(forKey: "restoreSortOption") ?? ""
        let restored = SortOption(rawValue: saved) ?? .nameAscending
        self.currentSortOption = [SortOption.nameAscending, .nameDescending].contains(restored) ? restored : .nameAscending
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

    /// Set sort option — didSet handles persistence and list refresh.
    func setSortOption(_ option: SortOption) {
        guard supportedSortOptions.contains(option) else { return }
        currentSortOption = option
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
        // Use the incoming backup directly — it carries the latest isSelected state.
        // Do NOT look up in availableBackups: that array may not yet reflect this change.
        selectedBackup = backup

        // Keep availableBackups in sync so future handleBackupsUpdate lookups are consistent.
        if let backup, let idx = availableBackups.firstIndex(where: { $0.id == backup.id }) {
            availableBackups[idx] = backup
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

        let filtered: [BackupAppInfo] = if searchText.isEmpty {
            backup.apps
        } else {
            backup.apps.filter { app in
                app.name.localizedCaseInsensitiveContains(searchText) ||
                    app.bundleId.localizedCaseInsensitiveContains(searchText)
            }
        }

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
