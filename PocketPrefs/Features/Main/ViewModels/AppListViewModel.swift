//
//  AppListViewModel.swift
//  PocketPrefs
//
//  Backup app list state management with sorting and persistence
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class AppListViewModel {
    // MARK: - UI State

    var searchText = ""

    // MARK: - Persistent Sort Option

    var currentSortOption: SortOption = .nameAscending {
        didSet {
            guard oldValue != currentSortOption else { return }
            sortOptionRawValue = currentSortOption.rawValue
        }
    }

    @ObservationIgnored
    @AppStorage("backupSortOption") private var sortOptionRawValue: String = SortOption.nameAscending.rawValue

    // MARK: - Dependencies

    private weak var coordinator: MainCoordinator?

    // MARK: - Computed from Coordinator

    private var sourceApps: [AppConfig] {
        coordinator?.apps ?? []
    }

    var filteredApps: [AppConfig] {
        let base: [AppConfig] = searchText.isEmpty
            ? sourceApps
            : sourceApps.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                    $0.bundleId.localizedCaseInsensitiveContains(searchText)
            }
        return currentSortOption.apply(to: base)
    }

    var cachedAllSelected: Bool {
        let installed = sourceApps.filter(\.isInstalled)
        return !installed.isEmpty && installed.allSatisfy(\.isSelected)
    }

    var cachedSelectedCount: Int {
        sourceApps.count(where: { $0.isSelected })
    }

    var totalCount: Int {
        sourceApps.count
    }

    var installedCount: Int {
        sourceApps.filter(\.isInstalled).count
    }

    // MARK: - Initialization

    init(coordinator: MainCoordinator) {
        self.coordinator = coordinator
        let saved = UserDefaults.standard.string(forKey: "backupSortOption") ?? ""
        self.currentSortOption = SortOption(rawValue: saved) ?? .nameAscending
    }

    // MARK: - Public Interface

    func setSortOption(_ option: SortOption) {
        currentSortOption = option
    }

    func toggleSelection(for app: AppConfig) {
        coordinator?.toggleSelection(for: app)
    }

    func toggleSelectAll() {
        guard let coordinator else { return }
        if cachedAllSelected {
            coordinator.deselectAll()
        } else {
            coordinator.selectAll()
        }
    }

    func deleteApp(_ app: AppConfig) {
        coordinator?.deleteApp(app)
    }
}
