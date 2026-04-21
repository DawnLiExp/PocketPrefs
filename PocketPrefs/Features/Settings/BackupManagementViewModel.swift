//
//  BackupManagementViewModel.swift
//  PocketPrefs
//
//  State and business logic for the Backup Management settings tab.
//

import Foundation
import os.log
import SwiftUI

@Observable
@MainActor
final class BackupManagementViewModel {
    // MARK: - State

    var backups: [BackupInfo] = []

    /// Left-column checkbox multi-selection (used for merge / batch delete).
    var selectedBackupIds: Set<String> = []

    /// Backing ID for detailBackup — only the identifier is stored, not the value copy.
    /// Computed property `detailBackup` always derives from `backups`, ensuring the
    /// right-column UI reflects the latest app count after any mutation.
    private var detailBackupId: String?

    /// Right-column detail target (independent from checkbox selection).
    /// Precondition: `backups` must be populated before this returns a non-nil value.
    var detailBackup: BackupInfo? {
        backups.first(where: { $0.id == detailBackupId }) ?? backups.first
    }

    /// Right-column app-level multi-selection (used for batch delete).
    var selectedDetailAppIds: Set<String> = []

    /// Inline delete confirmation for a backup row (left column).
    var pendingDeleteBackupId: String?
    var pendingAlert: AlertModel?

    // MARK: - Size Caches

    /// Backup directory path → formatted total size string.
    var backupSizeCache: [String: String] = [:]

    /// App sub-directory path → formatted size string.
    var appSizeCache: [String: String] = [:]

    var isLoading = false
    var isRefreshing = false
    var isMerging = false

    // MARK: - Computed

    var canMerge: Bool {
        selectedBackupIds.count >= 2
    }

    var canBatchDelete: Bool {
        !selectedBackupIds.isEmpty
    }

    var selectedCount: Int {
        selectedBackupIds.count
    }

    var selectedDetailCount: Int {
        selectedDetailAppIds.count
    }

    var canRefresh: Bool {
        !isLoading && !isRefreshing && !isMerging
    }

    // MARK: - Dependencies

    private let backupService = BackupService()
    private let managementService = BackupManagementService()
    private let fileOps = FileOperationService.shared
    private let logger = Logger(subsystem: "com.me2.PocketPrefs", category: "BackupManagementViewModel")
    @ObservationIgnored private var pendingMutationTasks: [UUID: Task<Void, Never>] = [:]

    // MARK: - Load

    func loadBackups() async {
        isLoading = true

        backups = await backupService.scanBackups()

        // detailBackup is a computed property derived from backups.
        // If detailBackupId still matches a backup, it is preserved automatically.
        // On first load (detailBackupId == nil), falls back to backups.first via computed property.
        if detailBackupId == nil {
            detailBackupId = backups.first?.id
        }

        selectedDetailAppIds.removeAll()

        pendingDeleteBackupId = nil
        isLoading = false

        await computeBackupSizes()

        if let detail = detailBackup {
            await computeAppSizes(for: detail)
        }
    }

    // MARK: - Size Computation

    private func computeBackupSizes() async {
        for backup in backups where backupSizeCache[backup.id] == nil {
            let size = await fileOps.calculateFileSize(at: backup.path)
            backupSizeCache[backup.id] = size
        }
    }

    private func computeAppSizes(for backup: BackupInfo) async {
        for app in backup.apps where appSizeCache[app.id] == nil {
            let size = await fileOps.calculateFileSize(at: app.path)
            appSizeCache[app.id] = size
        }
    }

    // MARK: - Backup Selection (left column)

    func toggleBackupSelection(_ id: String) {
        if selectedBackupIds.contains(id) {
            selectedBackupIds.remove(id)
        } else {
            selectedBackupIds.insert(id)
        }
    }

    /// Switches the right-column detail view; resets both pending-delete and app selection.
    func selectDetailBackup(_ backup: BackupInfo) {
        detailBackupId = backup.id
        pendingDeleteBackupId = nil
        selectedDetailAppIds.removeAll()
        Task { await computeAppSizes(for: backup) }
    }

    // MARK: - App Selection (right column)

    func toggleDetailAppSelection(_ id: String) {
        if selectedDetailAppIds.contains(id) {
            selectedDetailAppIds.remove(id)
        } else {
            selectedDetailAppIds.insert(id)
        }
    }

    func clearDetailSelection() {
        selectedDetailAppIds.removeAll()
    }

    // MARK: - Delete Backup (left-column inline two-step)

    func handleDeleteBackup(_ backup: BackupInfo) async {
        if pendingDeleteBackupId == backup.id {
            do {
                try await managementService.deleteBackup(backup)
                backupSizeCache.removeValue(forKey: backup.id)
                pendingDeleteBackupId = nil
                await loadBackups()
            } catch {
                logger.error("Delete backup failed: \(error)")
                pendingAlert = AlertModel.info(
                    title: String(localized: "Error"),
                    message: error.localizedDescription
                )
            }
        } else {
            pendingDeleteBackupId = backup.id
        }
    }

    func resetPendingDeleteBackup() {
        pendingDeleteBackupId = nil
    }

    // MARK: - Batch Delete Apps (right-column confirmation)

    /// Precondition: `detailBackup` must be non-nil and `selectedDetailAppIds` must be non-empty.
    func deleteSelectedDetailApps() {
        guard let backup = detailBackup else { return }
        let toDelete = backup.apps.filter { selectedDetailAppIds.contains($0.id) }
        guard !toDelete.isEmpty else { return }

        pendingAlert = AlertModel(
            title: String(localized: "Settings_Delete_Confirmation_Title"),
            message: String(
                localized: "Backup_Management_Delete_Apps_Message",
                defaultValue: "Delete \(toDelete.count) selected app backup(s) from this backup? This action cannot be undone."
            ),
            primaryLabel: String(localized: "Common_Delete"),
            style: .destructive,
            primaryAction: { [weak self] in
                self?.executeDeleteDetailApps(toDelete)
            }
        )
    }

    // MARK: - Batch Delete Backups (toolbar confirmation)

    func batchDeleteSelectedBackups() {
        let toDelete = backups.filter { selectedBackupIds.contains($0.id) }
        guard !toDelete.isEmpty else { return }

        pendingAlert = AlertModel(
            title: String(localized: "Backup_Management_Batch_Delete_Title"),
            message: String(
                localized: "Backup_Management_Batch_Delete_Message",
                defaultValue: "Delete \(toDelete.count) selected backups? This action cannot be undone."
            ),
            primaryLabel: String(localized: "Common_Delete"),
            style: .destructive,
            primaryAction: { [weak self] in
                self?.executeBatchDeleteBackups(toDelete)
            }
        )
    }

    // MARK: - Merge (confirmation)

    func performMerge() {
        let toMerge = backups.filter { selectedBackupIds.contains($0.id) }
        guard toMerge.count >= 2 else { return }

        var uniqueBundleIds = Set<String>()
        toMerge.forEach { $0.apps.forEach { uniqueBundleIds.insert($0.bundleId) } }

        pendingAlert = AlertModel(
            title: String(
                localized: "Backup_Management_Merge_Title",
                defaultValue: "Merge \(toMerge.count) Backups?"
            ),
            message: String(
                localized: "Backup_Management_Merge_Message",
                defaultValue: "Will merge \(toMerge.count) backups containing \(uniqueBundleIds.count) apps. Same app keeps the newest version. Original backups are preserved."
            ),
            primaryLabel: String(localized: "Backup_Management_Merge_Button"),
            style: .confirm,
            primaryAction: { [weak self] in
                self?.executeMerge(toMerge)
            }
        )
    }

    // MARK: - Refresh

    func refresh() async {
        guard canRefresh else { return }

        isRefreshing = true
        let startedAt = Date()
        defer { isRefreshing = false }

        await loadBackups()

        let minimumFeedbackDuration = 0.35
        let elapsed = Date().timeIntervalSince(startedAt)
        let remaining = minimumFeedbackDuration - elapsed

        if remaining > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
    }

    /// Waits until all tracked mutation tasks have completed.
    func waitForPendingMutations() async {
        while true {
            let pendingTasks = Array(pendingMutationTasks.values)
            guard !pendingTasks.isEmpty else { return }

            for task in pendingTasks {
                await task.value
            }
        }
    }

    // MARK: - Private Helpers

    private func runTrackedMutation(_ operation: @escaping @MainActor () async -> Void) {
        let taskId = UUID()
        let task = Task { @MainActor [weak self] in
            defer { self?.pendingMutationTasks.removeValue(forKey: taskId) }
            await operation()
        }
        pendingMutationTasks[taskId] = task
    }

    private func executeDeleteDetailApps(_ toDelete: [BackupAppInfo]) {
        runTrackedMutation { [weak self] in
            guard let self else { return }
            self.isLoading = true
            defer { self.isLoading = false }

            for app in toDelete {
                try? await self.managementService.deleteAppFromBackup(app)
                self.appSizeCache.removeValue(forKey: app.id)
            }
            self.selectedDetailAppIds.removeAll()
            await self.loadBackups()
        }
    }

    private func executeBatchDeleteBackups(_ toDelete: [BackupInfo]) {
        runTrackedMutation { [weak self] in
            guard let self else { return }
            self.isLoading = true
            defer { self.isLoading = false }

            for backup in toDelete {
                try? await self.managementService.deleteBackup(backup)
                self.backupSizeCache.removeValue(forKey: backup.id)
            }
            await self.loadBackups()
        }
    }

    private func executeMerge(_ toMerge: [BackupInfo]) {
        runTrackedMutation { [weak self] in
            guard let self else { return }
            self.isMerging = true
            defer { self.isMerging = false }

            do {
                _ = try await self.managementService.mergeBackups(toMerge)
                await self.loadBackups()
            } catch {
                self.logger.error("Merge failed: \(error)")
                self.pendingAlert = AlertModel.info(
                    title: String(localized: "Error"),
                    message: error.localizedDescription
                )
            }
        }
    }
}
