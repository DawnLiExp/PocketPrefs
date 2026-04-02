//
//  BackupManagementService.swift
//  PocketPrefs
//
//  Disk operations for backup deletion and merge.
//

import Foundation
import os.log

actor BackupManagementService {
    private let fileManager = FileManager.default
    private let fileOps = FileOperationService.shared
    private let backupService = BackupService()
    private let logger = Logger(subsystem: "com.pocketprefs", category: "BackupManagementService")

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
        // ── Step 1: Sort descending so newest entries are processed first
        let sorted = backups.sorted { $0.date > $1.date }

        // ── Step 2: Build bundleId → newest BackupAppInfo map
        var appMap: [String: BackupAppInfo] = [:]
        for backup in sorted {
            for app in backup.apps where appMap[app.bundleId] == nil {
                appMap[app.bundleId] = app
            }
        }

        // ── Step 3: Resolve destination base directory
        let resolvedBase = if let baseDir {
            baseDir
        } else {
            await PreferencesManager.shared.getBackupDirectory()
        }

        // ── Step 4: Create new backup directory
        let timestamp = BackupService.dateFormatter.string(from: Date())
        let newDirName = "\(BackupService.Config.backupPrefix)\(timestamp)"
        let newBackupPath = "\(resolvedBase)/\(newDirName)"
        try await fileOps.createDirectory(at: newBackupPath)
        logger.info("Created merge destination: \(newBackupPath)")

        // ── Step 5: Copy each winning app directory into new backup
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
