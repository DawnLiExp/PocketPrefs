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
    
    // Perform restore with async/await and TaskGroup
    func performRestore(backup: BackupInfo) async -> RestoreResult {
        let selectedApps = backup.apps.filter { $0.isSelected }
        
        guard !selectedApps.isEmpty else {
            logger.error("No apps selected for restore")
            return RestoreResult(successCount: 0, failedApps: [], totalProcessed: 0)
        }
        
        var successCount = 0
        var failedApps: [(String, Error)] = []
        
        // Restore apps concurrently with limited concurrency
        await withTaskGroup(of: (String, Result<Void, Error>).self) { group in
            // Limit concurrent operations
            let maxConcurrent = 4
            var activeTaskCount = 0
            var appIterator = selectedApps.makeIterator()
            
            while let app = appIterator.next() {
                if activeTaskCount >= maxConcurrent {
                    // Wait for one task to complete before adding more
                    if let (appName, result) = await group.next() {
                        activeTaskCount -= 1
                        handleRestoreResult(appName: appName, result: result,
                                          successCount: &successCount, failedApps: &failedApps)
                    }
                }
                
                group.addTask {
                    let result = await self.restoreSingleApp(app)
                    return (app.name, result)
                }
                activeTaskCount += 1
            }
            
            // Process remaining tasks
            for await (appName, result) in group {
                handleRestoreResult(appName: appName, result: result,
                                  successCount: &successCount, failedApps: &failedApps)
            }
        }
        
        return RestoreResult(
            successCount: successCount,
            failedApps: failedApps,
            totalProcessed: selectedApps.count
        )
    }
    
    private func handleRestoreResult(appName: String, result: Result<Void, Error>,
                                    successCount: inout Int, failedApps: inout [(String, Error)]) {
        switch result {
        case .success:
            successCount += 1
            logger.info("Successfully restored: \(appName)")
        case .failure(let error):
            failedApps.append((appName, error))
            logger.error("Failed to restore \(appName): \(error)")
        }
    }
    
    // Restore a single app
    private func restoreSingleApp(_ app: BackupAppInfo) async -> Result<Void, Error> {
        do {
            // Restore config files concurrently
            try await withThrowingTaskGroup(of: Void.self) { group in
                for originalPath in app.configPaths {
                    group.addTask {
                        let expandedPath = NSString(string: originalPath).expandingTildeInPath
                        let fileName = URL(fileURLWithPath: expandedPath).lastPathComponent
                        let sourcePath = "\(app.path)/\(fileName)"
                        
                        // Check file existence through fileOps
                        if await self.fileOps.fileExists(at: sourcePath) {
                            // Backup existing file
                            try await self.fileOps.backupExistingFile(expandedPath)
                            
                            // Restore file
                            try await self.fileOps.copyFile(from: sourcePath, to: expandedPath)
                        }
                    }
                }
                
                try await group.waitForAll()
            }
            
            return .success(())
        } catch {
            return .failure(AppError.restoreFailed(app: app.name, reason: error.localizedDescription))
        }
    }
}
