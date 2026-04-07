//
//  AppListViewModel.swift
//  PocketPrefs
//
//  Backup app list state management with sorting and persistence.
//
//  Architecture note — two-tier property strategy:
//  - filteredApps / apps: computed properties that read coordinator directly.
//    SwiftUI tracks coordinator.apps through these and re-renders the list immediately.
//  - cachedAllSelected / cachedSelectedCount: stored properties updated synchronously
//    from every action method (toggleSelectAll, toggleSelection) and on appsUpdated events.
//    This guarantees the Toggle and count text in AppListHeader re-render in the same
//    runloop cycle as the user action, avoiding the async-delay visual glitch (Bug 1).
//    Using computed properties for these does NOT fix Bug 1 because the Toggle's Binding
//    closure runs in Toggle's own observation context, not AppListHeader's body context,
//    so AppListHeader never receives the SwiftUI invalidation signal.
//

import Foundation
import os.log
import SwiftUI

@MainActor
@Observable
final class AppListViewModel {
    // MARK: - Stored: User Input

    var searchText = ""

    // MARK: - Stored: Toggle / Count State

    //
    // IMPORTANT: Must be updated synchronously in every mutating method.
    // Do NOT convert to computed properties — see architecture note in file header.

    var cachedAllSelected = false
    var cachedSelectedCount = 0

    // MARK: - Persistent Sort Option

    /// Observable stored property — @Observable macro tracks this for UI re-renders.
    /// didSet syncs the new value to UserDefaults via @AppStorage.
    var currentSortOption: SortOption = .nameAscending {
        didSet {
            guard oldValue != currentSortOption else { return }
            sortOptionRawValue = currentSortOption.rawValue
        }
    }

    /// Persistence only — @ObservationIgnored prevents macro conflicts with @AppStorage.
    @ObservationIgnored
    @AppStorage("backupSortOption") private var sortOptionRawValue: String = SortOption.nameAscending.rawValue

    // MARK: - Computed: List Data

    //
    // Read coordinator.apps directly so ForEach always reflects the latest state
    // without any intermediate copy or async hop.

    var apps: [AppConfig] {
        coordinator?.currentApps ?? []
    }

    var filteredApps: [AppConfig] {
        let source = coordinator?.currentApps ?? []
        let filtered: [AppConfig] = if searchText.isEmpty {
            source
        } else {
            source.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.bundleId.localizedCaseInsensitiveContains(searchText)
            }
        }
        return currentSortOption.apply(to: filtered)
    }

    // MARK: - Dependencies

    private weak var coordinator: MainCoordinator?
    private let logger = Logger(subsystem: "com.me2.PocketPrefs", category: "AppListViewModel")

    @ObservationIgnored private var eventTask: Task<Void, Never>?

    // MARK: - Initialization

    init(coordinator: MainCoordinator) {
        self.coordinator = coordinator
        let saved = UserDefaults.standard.string(forKey: "backupSortOption") ?? ""
        self.currentSortOption = SortOption(rawValue: saved) ?? .nameAscending
        subscribeToEvents()
    }

    deinit {
        eventTask?.cancel()
    }

    // MARK: - Event Subscription

    //
    // Subscribes only to appsUpdated — handles external app list changes
    // (e.g., loadApps after settings close, app added/removed).
    // User-initiated actions update cached state synchronously at the call site
    // and do not rely on this path for immediate UI feedback.

    private func subscribeToEvents() {
        eventTask?.cancel()
        eventTask = Task { [weak self] in
            guard let self else { return }
            for await event in CoordinatorEventPublisher.shared.subscribe() {
                guard !Task.isCancelled else { break }
                if case .appsUpdated(let apps) = event {
                    self.refreshCachedState(from: apps)
                }
            }
        }
    }

    // MARK: - Lifecycle

    func onAppear() {
        refreshCachedState(from: coordinator?.currentApps ?? [])
    }

    // MARK: - Public Interface

    func setSortOption(_ option: SortOption) {
        currentSortOption = option
    }

    func toggleSelection(for app: AppConfig) {
        coordinator?.toggleSelection(for: app)
        refreshCachedState(from: coordinator?.currentApps ?? [])
    }

    func toggleSelectAll() {
        guard let coordinator else { return }
        if cachedAllSelected {
            coordinator.deselectAll()
        } else {
            coordinator.selectAll()
        }
        // Synchronous update — same runloop cycle as the user action.
        refreshCachedState(from: coordinator.currentApps)
    }

    func deleteApp(_ app: AppConfig) {
        coordinator?.deleteApp(app)
    }

    // MARK: - Private

    private func refreshCachedState(from apps: [AppConfig]) {
        let installed = apps.filter(\.isInstalled)
        cachedAllSelected = !installed.isEmpty && installed.allSatisfy(\.isSelected)
        cachedSelectedCount = apps.count(where: \.isSelected)
    }
}
