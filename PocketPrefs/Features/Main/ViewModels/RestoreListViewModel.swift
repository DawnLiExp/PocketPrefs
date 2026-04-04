//
//  RestoreListViewModel.swift
//  PocketPrefs
//
//  Restore backup list state management with sorting and persistence
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class RestoreListViewModel {
    // MARK: - UI State

    var searchText = ""
    var isRefreshing = false

    // MARK: - Persistent Sort Option

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

    @ObservationIgnored
    @AppStorage("restoreSortOption") private var sortOptionRawValue: String = SortOption.nameAscending.rawValue

    // MARK: - Public Properties

    var supportedSortOptions: [SortOption] {
        [.nameAscending, .nameDescending]
    }

    // MARK: - Dependencies

    private weak var coordinator: MainCoordinator?

    // MARK: - Computed from Coordinator

    var selectedBackup: BackupInfo? {
        coordinator?.selectedBackup
    }

    var availableBackups: [BackupInfo] {
        coordinator?.availableBackups ?? []
    }

    var filteredApps: [BackupAppInfo] {
        guard let backup = selectedBackup else { return [] }
        let base: [BackupAppInfo] = searchText.isEmpty
            ? backup.apps
            : backup.apps.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                    $0.bundleId.localizedCaseInsensitiveContains(searchText)
            }
        return currentSortOption.apply(to: base)
    }

    var cachedAllSelected: Bool {
        !filteredApps.isEmpty && filteredApps.allSatisfy(\.isSelected)
    }

    var cachedSelectedCount: Int {
        filteredApps.count(where: { $0.isSelected })
    }

    var cachedTotalCount: Int {
        filteredApps.count
    }

    // MARK: - Initialization

    init(coordinator: MainCoordinator) {
        self.coordinator = coordinator
        let saved = UserDefaults.standard.string(forKey: "restoreSortOption") ?? ""
        let restored = SortOption(rawValue: saved) ?? .nameAscending
        self.currentSortOption = [SortOption.nameAscending, .nameDescending].contains(restored) ? restored : .nameAscending
    }

    // MARK: - Public Interface

    func onSettingsClose() {
        coordinator?.deselectAllRestoreApps()
        searchText = ""
    }

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
}
