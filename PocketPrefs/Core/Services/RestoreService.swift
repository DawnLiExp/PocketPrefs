//
//  RestoreService.swift
//  PocketPrefs
//
//  Restore operations service
//

import Foundation
import os.log

actor RestoreService {
    private let logger = Logger(subsystem: "com.me2.PocketPrefs", category: "RestoreService")
    private let fileOps = FileOperationService.shared
    
    private enum Config {
        static let batchSize = 4
    }
    
    // MARK: - Public Interface
    
    /// Perform restore operation from selected backup
    /// - Parameters:
    ///   - backup: Backup info containing apps to restore
    ///   - onProgress: Progress callback for UI updates
    /// - Returns: Restore result with success/failure counts
    func performRestore(
        backup: BackupInfo,
        createBackupBeforeRestore: Bool = true,
        onProgress: ProgressHandler? = nil,
    ) async -> RestoreResult {
        let selectedApps = backup.apps.filter(\.isSelected)
        
        guard !selectedApps.isEmpty else {
            logger.warning("No apps selected for restore")
            return RestoreResult(successCount: 0, failedApps: [], totalProcessed: 0)
        }
        
        logger.info("Starting restore: \(selectedApps.count) apps")
        await onProgress?(.idle)
        
        return await processRestore(apps: selectedApps, createBackupBeforeRestore: createBackupBeforeRestore, onProgress: onProgress)
    }
    
    // MARK: - Private Implementation
    
    /// Process restore with batch-controlled concurrency
    private func processRestore(
        apps: [BackupAppInfo],
        createBackupBeforeRestore: Bool,
        onProgress: ProgressHandler?,
    ) async -> RestoreResult {
        var successCount = 0
        var failedApps: [(String, Error)] = []
        var completedCount = 0
        let totalApps = apps.count
        
        let batches = apps.chunked(into: Config.batchSize)
        
        // Batches execute sequentially, apps within batch execute concurrently
        for batch in batches {
            await withTaskGroup(of: RestoreTaskResult.self) { group in
                for app in batch {
                    group.addTask {
                        await self.restoreSingleApp(app, createBackupBeforeRestore: createBackupBeforeRestore)
                    }
                }
                
                for await result in group {
                    completedCount += 1
                    
                    switch result.outcome {
                    case .success:
                        successCount += 1
                        logger.info("Restored: \(result.appName)")
                    case .failure(let error):
                        failedApps.append((result.appName, error))
                        logger.error("Restore failed: \(result.appName) - \(error.localizedDescription)")
                    }
                    
                    await reportProgress(
                        completed: completedCount,
                        total: totalApps,
                        appName: result.appName,
                        onProgress: onProgress,
                    )
                }
            }
        }
        
        logger.info("Restore completed: \(successCount)/\(totalApps) succeeded")
        
        return RestoreResult(
            successCount: successCount,
            failedApps: failedApps,
            totalProcessed: totalApps,
        )
    }
    
    private func restoreSingleApp(_ app: BackupAppInfo, createBackupBeforeRestore: Bool) async -> RestoreTaskResult {
        do {
            try await restoreConfigFiles(for: app, createBackupBeforeRestore: createBackupBeforeRestore)
            return RestoreTaskResult(appName: app.name, outcome: .success(()))
        } catch {
            let wrappedError = AppError.restoreFailed(
                app: app.name,
                reason: error.localizedDescription,
            )
            return RestoreTaskResult(appName: app.name, outcome: .failure(wrappedError))
        }
    }
    
    /// Restore all config files concurrently
    private func restoreConfigFiles(for app: BackupAppInfo, createBackupBeforeRestore: Bool) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for originalPath in app.configPaths {
                group.addTask {
                    try await self.restoreSingleConfigFile(
                        originalPath: originalPath,
                        backupRoot: app.path,
                        createBackupBeforeRestore: createBackupBeforeRestore,
                    )
                }
            }
            
            try await group.waitForAll()
        }
    }
    
    private func restoreSingleConfigFile(
        originalPath: String,
        backupRoot: String,
        createBackupBeforeRestore: Bool,
    ) async throws {
        let expandedPath = NSString(string: originalPath).expandingTildeInPath
        let fileName = URL(fileURLWithPath: expandedPath).lastPathComponent
        let sourcePath = "\(backupRoot)/\(fileName)"
        
        guard await fileOps.fileExists(at: sourcePath) else {
            logger.debug("Config file not in backup: \(fileName)")
            return
        }
        
        // Backup existing file before overwriting (if enabled)
        if createBackupBeforeRestore {
            try await fileOps.backupExistingFile(expandedPath)
        }
        try await fileOps.copyFile(from: sourcePath, to: expandedPath)
    }
    
    private func reportProgress(
        completed: Int,
        total: Int,
        appName: String,
        onProgress: ProgressHandler?,
    ) async {
        let progress = ProgressUpdate(
            completed: completed,
            total: total,
            message: String(
                format: String(localized: "Restore_Progress_Message", defaultValue: "Restoring \(appName)..."),
                appName,
            ),
        )
        await onProgress?(progress)
    }
}

// MARK: - Internal Types

private struct RestoreTaskResult {
    let appName: String
    let outcome: Result<Void, Error>
}
