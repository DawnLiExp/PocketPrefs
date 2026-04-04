//
//  BackupManagementService.swift
//  PocketPrefs
//
//  Disk operations for backup deletion and merge.
//
//  Invariant: "valid app backup" = subdirectory containing a readable app_config.json.
//  Physical emptiness (e.g. only .DS_Store remains) is NOT sufficient to keep a backup directory.
//

import Foundation
import os.log

// MARK: - Delete Apps Outcome

/// Result model returned by `deleteAppsFromBackup(_:in:)`.
/// Partial failures are captured in `failedApps`; the caller decides how to surface them.
struct DeleteAppsOutcome {
    let deletedCount: Int
    let failedApps: [(name: String, error: Error)]
    /// `true` when the parent backup directory was removed because no valid app backups remained.
    let parentBackupDeleted: Bool
}

// MARK: - Service

actor BackupManagementService {
    private let fileManager = FileManager.default
    private let fileOps = FileOperationService.shared
    private let backupService = BackupService()
    private let logger = Logger(subsystem: "com.me2.PocketPrefs", category: "BackupManagementService")

    // MARK: - Delete

    /// Deletes the entire backup directory at `backup.path`.
    func deleteBackup(_ backup: BackupInfo) async throws {
        try fileManager.removeItem(atPath: backup.path)
        logger.info("Deleted backup: \(backup.name)")
    }

    /// Deletes a single app sub-directory from within a backup.
    func deleteAppFromBackup(_ app: BackupAppInfo) async throws {
        try fileManager.removeItem(atPath: app.path)
        logger.info("Deleted app from backup: \(app.name)")
    }

    /// Deletes multiple app sub-directories from a backup, then removes the parent backup
    /// directory if no valid app backups remain.
    ///
    /// Precondition: all `apps` must belong to `backup` (their paths are sub-paths of `backup.path`).
    /// Postcondition: each successfully deleted app directory is gone from disk.
    ///   If the resulting backup contains no valid app backups, `backup.path` is also deleted.
    ///   Individual deletion failures are captured in `DeleteAppsOutcome.failedApps`; they do not
    ///   abort the operation.
    /// - Returns: `DeleteAppsOutcome` describing what was deleted and whether the parent was removed.
    func deleteAppsFromBackup(_ apps: [BackupAppInfo], in backup: BackupInfo) async -> DeleteAppsOutcome {
        guard !apps.isEmpty else {
            return DeleteAppsOutcome(deletedCount: 0, failedApps: [], parentBackupDeleted: false)
        }

        // ── Step 1: Delete each app sub-directory ─────────────────────────────
        var deletedCount = 0
        var failedApps: [(name: String, error: Error)] = []

        for app in apps {
            do {
                try fileManager.removeItem(atPath: app.path)
                deletedCount += 1
                logger.info("Deleted app from backup: \(app.name)")
            } catch {
                failedApps.append((app.name, error))
                logger.error("Failed to delete app '\(app.name)': \(error)")
            }
        }

        // ── Step 2: Remove parent backup directory if no valid app backups remain ──
        let parentDeleted = await cleanupBackupDirectoryIfNeeded(backup)

        logger.info("deleteAppsFromBackup: \(deletedCount) deleted, \(failedApps.count) failed, parent removed: \(parentDeleted)")
        return DeleteAppsOutcome(
            deletedCount: deletedCount,
            failedApps: failedApps,
            parentBackupDeleted: parentDeleted
        )
    }

    /// Removes the backup directory if it contains no valid app backups.
    ///
    /// "Valid app backup" is defined as a sub-directory containing a readable `app_config.json`.
    /// Physical emptiness alone (e.g. only `.DS_Store` remains) is not sufficient to keep the
    /// directory; the logical content is what matters.
    ///
    /// Idempotent: returns `false` without error if the directory no longer exists on disk.
    /// - Returns: `true` if the directory was deleted, `false` otherwise.
    @discardableResult
    func cleanupBackupDirectoryIfNeeded(_ backup: BackupInfo) async -> Bool {
        guard fileManager.fileExists(atPath: backup.path) else {
            logger.info("Backup directory already absent, skipping cleanup: \(backup.name)")
            return false
        }

        let remainingApps = await backupService.scanAppsInBackup(at: backup.path)
        guard remainingApps.isEmpty else {
            logger.info("Backup '\(backup.name)' retains \(remainingApps.count) valid app(s); skipping cleanup")
            return false
        }

        do {
            try fileManager.removeItem(atPath: backup.path)
            logger.info("Cleaned up empty backup directory: \(backup.name)")
            return true
        } catch {
            logger.error("Failed to cleanup backup directory '\(backup.name)': \(error)")
            return false
        }
    }

    // MARK: - Merge

    /// Merges multiple backups into a new backup using newest-wins strategy.
    ///
    /// Precondition: `backups.count >= 2`; each `backup.path` must exist on disk.
    /// Postcondition: A new backup directory is created under `baseDir`.
    ///   Original backups are **not** deleted.
    /// - Parameters:
    ///   - backups: Backups to merge (must contain ≥ 2 entries).
    ///   - baseDir: Directory to create the merged backup in. Defaults to the user's
    ///     configured backup directory when `nil`. Pass an explicit path in tests.
    /// - Returns: Path of the newly created backup directory.
    func mergeBackups(_ backups: [BackupInfo], baseDir: String? = nil) async throws -> String {
        // ── Step 1: Sort descending so newest entries are processed first ──────
        let sorted = backups.sorted { $0.date > $1.date }

        // ── Step 2: Build bundleId → newest BackupAppInfo map ─────────────────
        var appMap: [String: BackupAppInfo] = [:]
        for backup in sorted {
            for app in backup.apps where appMap[app.bundleId] == nil {
                appMap[app.bundleId] = app
            }
        }

        // ── Step 3: Resolve destination base directory ─────────────────────────
        let resolvedBase = if let baseDir {
            baseDir
        } else {
            await PreferencesManager.shared.getBackupDirectory()
        }

        // ── Step 4: Create new backup directory ───────────────────────────────
        let timestamp = BackupService.dateFormatter.string(from: Date())
        let newDirName = "\(BackupService.Config.backupPrefix)\(timestamp)"
        let newBackupPath = "\(resolvedBase)/\(newDirName)"
        try await fileOps.createDirectory(at: newBackupPath)
        logger.info("Created merge destination: \(newBackupPath)")

        // ── Step 5: Copy each winning app directory into new backup ────────────
        for (_, app) in appMap {
            let destName = await backupService.sanitizeName(app.name)
            let destURL = URL(fileURLWithPath: newBackupPath)
                .appendingPathComponent(destName)
            try fileManager.copyItem(
                at: URL(fileURLWithPath: app.path),
                to: destURL
            )
        }

        logger.info("Merge complete: \(appMap.count) apps → \(newDirName)")
        return newBackupPath
    }
}
