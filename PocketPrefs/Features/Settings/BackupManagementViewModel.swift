//
//  BackupManagementViewModel.swift
//  PocketPrefs
//
//  State and business logic for the Backup Management settings tab.
//

import AppKit
import Foundation
import os.log
import SwiftUI

@Observable
@MainActor
final class BackupManagementViewModel {
    // MARK: - State

    var backups: [BackupInfo] = []

    /// Left-column checkbox multi-selection (used for merge / batch delete).
    var selectedBackupIds: Set<UUID> = []

    /// Right-column detail target (independent from checkbox selection).
    var detailBackup: BackupInfo?

    /// Right-column app-level multi-selection (used for batch delete).
    var selectedDetailAppIds: Set<UUID> = []

    /// Inline delete confirmation for a backup row (left column).
    var pendingDeleteBackupId: UUID?

    // MARK: Size caches keyed by path (stable across reloads)

    //
    // IMPORTANT: Must use `path` (not `BackupInfo/BackupAppInfo.id`) as key.
    // `id` is re-generated as a new UUID on every `scanBackups()` call,
    // which would invalidate all cached entries and cause visible size flicker.

    /// Backup directory path → formatted total size string.
    var backupSizeCache: [String: String] = [:]

    /// App sub-directory path → formatted size string.
    var appSizeCache: [String: String] = [:]

    var isLoading = false
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

    // MARK: - Dependencies

    private let backupService = BackupService()
    private let managementService = BackupManagementService()
    private let fileOps = FileOperationService.shared
    private let logger = Logger(subsystem: "com.me2.PocketPrefs", category: "BackupManagementViewModel")

    // MARK: - Load

    func loadBackups() async {
        isLoading = true

        // ── Capture state by path before reload ───────────────────────────────
        // BackupInfo.id is a new UUID on every scanBackups() call.
        // We must match by path to correctly reconcile selection and detail state.
        let selectedPaths = Set(
            backups.filter { selectedBackupIds.contains($0.id) }.map(\.path)
        )
        let detailPath = detailBackup?.path

        backups = await backupService.scanBackups()

        // ── Reconcile selectedBackupIds against new UUIDs ─────────────────────
        selectedBackupIds = Set(
            backups.filter { selectedPaths.contains($0.path) }.map(\.id)
        )

        // ── Reconcile detailBackup against new UUIDs ──────────────────────────
        if let detailPath {
            detailBackup = backups.first(where: { $0.path == detailPath }) ?? backups.first
        } else {
            detailBackup = backups.first
        }

        // ── App-level selection is invalidated on every reload ─────────────────
        // BackupAppInfo.id is also a new UUID on every scan.
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
        for backup in backups where backupSizeCache[backup.path] == nil {
            let size = await fileOps.calculateFileSize(at: backup.path)
            backupSizeCache[backup.path] = size
        }
    }

    private func computeAppSizes(for backup: BackupInfo) async {
        for app in backup.apps where appSizeCache[app.path] == nil {
            let size = await fileOps.calculateFileSize(at: app.path)
            appSizeCache[app.path] = size
        }
    }

    // MARK: - Backup Selection (left column)

    func toggleBackupSelection(_ id: UUID) {
        if selectedBackupIds.contains(id) {
            selectedBackupIds.remove(id)
        } else {
            selectedBackupIds.insert(id)
        }
    }

    /// Switches the right-column detail view; resets both pending-delete and app selection.
    func selectDetailBackup(_ backup: BackupInfo) {
        detailBackup = backup
        pendingDeleteBackupId = nil
        selectedDetailAppIds.removeAll()
        Task { await computeAppSizes(for: backup) }
    }

    // MARK: - App Selection (right column)

    func toggleDetailAppSelection(_ id: UUID) {
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
                backupSizeCache.removeValue(forKey: backup.path)
                pendingDeleteBackupId = nil
                await loadBackups()
            } catch {
                logger.error("Delete backup failed: \(error)")
                showErrorAlert(message: error.localizedDescription)
            }
        } else {
            pendingDeleteBackupId = backup.id
        }
    }

    func resetPendingDeleteBackup() {
        pendingDeleteBackupId = nil
    }

    // MARK: - Batch Delete Apps (right-column, NSAlert confirmation)

    /// Precondition: `detailBackup` must be non-nil and `selectedDetailAppIds` must be non-empty.
    func deleteSelectedDetailApps() async {
        guard let backup = detailBackup else { return }
        let toDelete = backup.apps.filter { selectedDetailAppIds.contains($0.id) }
        guard !toDelete.isEmpty else { return }

        let confirmed = await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText = String(localized: "Settings_Delete_Confirmation_Title")
            alert.informativeText = String(
                localized: "Backup_Management_Delete_Apps_Message",
                defaultValue: "Delete \(toDelete.count) selected app backup(s) from this backup? This action cannot be undone."
            )
            alert.alertStyle = .warning
            alert.addButton(withTitle: String(localized: "Common_Delete"))
            alert.addButton(withTitle: String(localized: "Common_Cancel"))
            continuation.resume(returning: alert.runModal() == .alertFirstButtonReturn)
        }

        guard confirmed else { return }

        isLoading = true
        for app in toDelete {
            try? await managementService.deleteAppFromBackup(app)
            appSizeCache.removeValue(forKey: app.path)
        }
        selectedDetailAppIds.removeAll()
        isLoading = false
        await loadBackups()
    }

    // MARK: - Batch Delete Backups (toolbar, NSAlert confirmation)

    func batchDeleteSelectedBackups() async {
        let toDelete = backups.filter { selectedBackupIds.contains($0.id) }
        guard !toDelete.isEmpty else { return }

        let confirmed = await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText = String(localized: "Backup_Management_Batch_Delete_Title")
            alert.informativeText = String(
                localized: "Backup_Management_Batch_Delete_Message",
                defaultValue: "Delete \(toDelete.count) selected backups? This action cannot be undone."
            )
            alert.alertStyle = .warning
            alert.addButton(withTitle: String(localized: "Common_Delete"))
            alert.addButton(withTitle: String(localized: "Common_Cancel"))
            continuation.resume(returning: alert.runModal() == .alertFirstButtonReturn)
        }

        guard confirmed else { return }

        isLoading = true
        for backup in toDelete {
            try? await managementService.deleteBackup(backup)
            backupSizeCache.removeValue(forKey: backup.path)
        }
        isLoading = false
        await loadBackups()
    }

    // MARK: - Merge (NSAlert confirmation)

    func performMerge() async {
        let toMerge = backups.filter { selectedBackupIds.contains($0.id) }
        guard toMerge.count >= 2 else { return }

        var uniqueBundleIds = Set<String>()
        toMerge.forEach { $0.apps.forEach { uniqueBundleIds.insert($0.bundleId) } }

        let confirmed = await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText = String(
                localized: "Backup_Management_Merge_Title",
                defaultValue: "Merge \(toMerge.count) Backups?"
            )
            alert.informativeText = String(
                localized: "Backup_Management_Merge_Message",
                defaultValue: "Will merge \(toMerge.count) backups containing \(uniqueBundleIds.count) apps. Same app keeps the newest version. Original backups are preserved."
            )
            alert.addButton(withTitle: String(localized: "Backup_Management_Merge_Button"))
            alert.addButton(withTitle: String(localized: "Common_Cancel"))
            continuation.resume(returning: alert.runModal() == .alertFirstButtonReturn)
        }

        guard confirmed else { return }

        isMerging = true
        do {
            _ = try await managementService.mergeBackups(toMerge)
            isMerging = false
            await loadBackups()
        } catch {
            isMerging = false
            logger.error("Merge failed: \(error)")
            showErrorAlert(message: error.localizedDescription)
        }
    }

    // MARK: - Refresh

    func refresh() async {
        await loadBackups()
    }

    // MARK: - Private Helpers

    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = String(localized: "Error")
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
