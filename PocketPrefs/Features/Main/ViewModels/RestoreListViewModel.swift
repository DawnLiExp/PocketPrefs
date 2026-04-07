//
//  RestoreListViewModel.swift
//  PocketPrefs
//
//  Restore backup list state management with sorting and persistence.
//
//  Architecture note — two-tier property strategy:
//  - filteredApps: computed property that reads selectedBackup directly.
//    SwiftUI tracks selectedBackup changes and re-renders the list immediately.
//  - cachedAllSelected / cachedSelectedCount / cachedTotalCount: stored properties
//    updated synchronously in action methods and asynchronously on coordinator events.
//    This guarantees Toggle and count text update in the same runloop as user actions
//    and avoids visual desync on select-all (Bug 2).
//

import Foundation
import Observation
import os.log
import SwiftUI

@MainActor
@Observable
final class RestoreListViewModel {
    // MARK: - Stored State

    var selectedBackup: BackupInfo?
    var availableBackups: [BackupInfo] = []
    var searchText = ""
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

    var filteredApps: [BackupAppInfo] {
        guard let backup = selectedBackup else { return [] }
        let source = backup.apps
        let filtered: [BackupAppInfo] = if searchText.isEmpty {
            source
        } else {
            source.filter { app in
                app.name.localizedCaseInsensitiveContains(searchText) ||
                    app.bundleId.localizedCaseInsensitiveContains(searchText)
            }
        }
        return currentSortOption.apply(to: filtered)
    }

    // MARK: - Dependencies

    private weak var coordinator: MainCoordinator?
    private let logger = Logger(subsystem: "com.me2.PocketPrefs", category: "RestoreListViewModel")
    @ObservationIgnored private var isObservingCoordinator = false

    // MARK: - Initialization

    init(coordinator: MainCoordinator) {
        self.coordinator = coordinator
        // Restore persisted sort option without triggering didSet
        let saved = UserDefaults.standard.string(forKey: "restoreSortOption") ?? ""
        let restored = SortOption(rawValue: saved) ?? .nameAscending
        self.currentSortOption = [SortOption.nameAscending, .nameDescending].contains(restored) ? restored : .nameAscending
    }

    // MARK: - Public Interface

    /// Initialize view state
    func onAppear() {
        syncFromCoordinator()
        refreshCachedState()
        startCoordinatorObservation()
    }

    func onSettingsClose() {
        guard let coordinator else { return }
        coordinator.deselectAllRestoreApps()
        syncFromCoordinator()
        refreshCachedState()
    }

    /// Set sort option — didSet handles persistence and list refresh.
    func setSortOption(_ option: SortOption) {
        guard supportedSortOptions.contains(option) else { return }
        currentSortOption = option
    }

    func toggleSelection(for app: BackupAppInfo) {
        coordinator?.toggleRestoreSelection(for: app)
        refreshCachedState(from: coordinator?.currentSelectedBackup?.apps ?? [])
    }

    func toggleSelectAll() {
        guard let coordinator else { return }

        if cachedAllSelected {
            coordinator.deselectAllRestoreApps()
        } else {
            coordinator.selectAllRestoreApps()
        }

        // Synchronous update — same runloop cycle as user action.
        refreshCachedState(from: coordinator.currentSelectedBackup?.apps ?? [])
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

    // MARK: - Private Implementation

    private func startCoordinatorObservation() {
        guard !isObservingCoordinator else { return }
        isObservingCoordinator = true
        observeCoordinatorState()
    }

    private func observeCoordinatorState() {
        withObservationTracking {
            _ = coordinator?.currentBackups
            _ = coordinator?.selectedBackup
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.syncFromCoordinator()
                self.refreshCachedState()
                self.observeCoordinatorState()
            }
        }
    }

    private func syncFromCoordinator() {
        guard let coordinator else {
            availableBackups = []
            selectedBackup = nil
            return
        }
        availableBackups = coordinator.currentBackups
        selectedBackup = coordinator.selectedBackup
    }

    private func refreshCachedState(from apps: [BackupAppInfo]? = nil) {
        let source = apps ?? selectedBackup?.apps ?? []
        let visible: [BackupAppInfo] = if searchText.isEmpty {
            source
        } else {
            source.filter { app in
                app.name.localizedCaseInsensitiveContains(searchText) ||
                    app.bundleId.localizedCaseInsensitiveContains(searchText)
            }
        }

        guard !visible.isEmpty else {
            cachedAllSelected = false
            cachedSelectedCount = 0
            cachedTotalCount = visible.count
            return
        }

        cachedTotalCount = visible.count
        cachedSelectedCount = visible.count(where: \.isSelected)
        cachedAllSelected = visible.allSatisfy(\.isSelected)
    }
}
