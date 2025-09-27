//
//  RestoreService.swift
//  PocketPrefs
//
//  Restore operations service
//

import Foundation
import os.log

actor RestoreService {
    private let logger = Logger(subsystem: "com.pocketprefs", category: "RestoreService")
    private let fileOps = FileOperationService.shared
    
    private enum Config {
        static let maxConcurrentOperations = 4
    }
    
    func performRestore(backup: BackupInfo) async -> RestoreResult {
        let selectedApps = backup.apps.filter { $0.isSelected }
        
        guard !selectedApps.isEmpty else {
            logger.error("No apps selected for restore")
            return RestoreResult(successCount: 0, failedApps: [], totalProcessed: 0)
        }
        
        var successCount = 0
        var failedApps: [(String, Error)] = []
        
        // Restore apps with controlled concurrency
        await withTaskGroup(of: (String, Result<Void, Error>).self) { group in
            for appBatch in selectedApps.chunked(into: Config.maxConcurrentOperations) {
                // Process batch concurrently
                for app in appBatch {
                    group.addTask {
                        let result = await self.restoreSingleApp(app)
                        return (app.name, result)
                    }
                }
                
                // Wait for batch completion
                for await (appName, result) in group {
                    switch result {
                    case .success:
                        successCount += 1
                        logger.info("Successfully restored: \(appName)")
                    case .failure(let error):
                        failedApps.append((appName, error))
                        logger.error("Failed to restore \(appName): \(error)")
                    }
                }
            }
        }
        
        return RestoreResult(
            successCount: successCount,
            failedApps: failedApps,
            totalProcessed: selectedApps.count
        )
    }
    
    private func restoreSingleApp(_ app: BackupAppInfo) async -> Result<Void, Error> {
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for originalPath in app.configPaths {
                    group.addTask {
                        let expandedPath = NSString(string: originalPath).expandingTildeInPath
                        let fileName = URL(fileURLWithPath: expandedPath).lastPathComponent
                        let sourcePath = "\(app.path)/\(fileName)"
                        
                        if await self.fileOps.fileExists(at: sourcePath) {
                            try await self.fileOps.backupExistingFile(expandedPath)
                            try await self.fileOps.copyFile(from: sourcePath, to: expandedPath)
                        }
                    }
                }
                
                try await group.waitForAll()
            }
            
            return .success(())
        } catch {
            return .failure(
                AppError.restoreFailed(
                    app: app.name,
                    reason: error.localizedDescription
                )
            )
        }
    }
}

// MARK: - Array Extension for Chunking

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
