//
//  BackupService.swift
//  PocketPrefs
//
//  Backup operations service
//

import Foundation
import os.log

actor BackupService {
    private let logger = Logger(subsystem: "com.pocketprefs", category: "BackupService")
    private let fileOps = FileOperationService.shared
    private let baseDir = NSHomeDirectory() + "/Documents/PocketPrefsBackups"
    
    // Perform backup with async/await and TaskGroup
    func performBackup(apps: [AppConfig]) async -> BackupResult {
        let selectedApps = apps.filter { $0.isSelected && $0.isInstalled }
        
        guard !selectedApps.isEmpty else {
            logger.error("No apps selected for backup")
            return BackupResult(successCount: 0, failedApps: [], totalProcessed: 0)
        }
        
        // Create backup directory
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let backupDir = "\(baseDir)/Backup_\(timestamp)"
        
        do {
            try await fileOps.createDirectory(at: backupDir)
            logger.info("Created backup directory: \(backupDir)")
        } catch {
            logger.error("Failed to create backup directory: \(error)")
            return BackupResult(
                successCount: 0,
                failedApps: selectedApps.map { ($0.name, error) },
                totalProcessed: selectedApps.count
            )
        }
        
        // Backup apps concurrently with TaskGroup
        var successCount = 0
        var failedApps: [(String, Error)] = []
        
        await withTaskGroup(of: (String, Result<Void, Error>).self) { group in
            for app in selectedApps {
                group.addTask {
                    let result = await self.backupSingleApp(app, to: backupDir)
                    return (app.name, result)
                }
            }
            
            for await (appName, result) in group {
                switch result {
                case .success:
                    successCount += 1
                    logger.info("Successfully backed up: \(appName)")
                case .failure(let error):
                    failedApps.append((appName, error))
                    logger.error("Failed to backup \(appName): \(error)")
                }
            }
        }
        
        return BackupResult(
            successCount: successCount,
            failedApps: failedApps,
            totalProcessed: selectedApps.count
        )
    }
    
    // Backup a single app
    private func backupSingleApp(_ app: AppConfig, to backupDir: String) async -> Result<Void, Error> {
        let appBackupDir = "\(backupDir)/\(app.name.replacingOccurrences(of: " ", with: "_"))"
        
        do {
            try await fileOps.createDirectory(at: appBackupDir)
            
            // Backup config files concurrently
            try await withThrowingTaskGroup(of: Void.self) { group in
                for path in app.configPaths {
                    group.addTask {
                        let expandedPath = NSString(string: path).expandingTildeInPath
                        
                        // Check file existence through fileOps
                        if await self.fileOps.fileExists(at: expandedPath) {
                            let fileName = URL(fileURLWithPath: expandedPath).lastPathComponent
                            let destPath = "\(appBackupDir)/\(fileName)"
                            try await self.fileOps.copyFile(from: expandedPath, to: destPath)
                        }
                    }
                }
                
                // Wait for all file operations
                try await group.waitForAll()
            }
            
            // Save app configuration
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let configData = try encoder.encode(app)
            let configURL = URL(fileURLWithPath: "\(appBackupDir)/app_config.json")
            try configData.write(to: configURL)
            
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    // Scan existing backups
    func scanBackups() async -> [BackupInfo] {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: baseDir) else {
            try? await fileOps.createDirectory(at: baseDir)
            return []
        }
        
        do {
            let backupDirs = try fileManager.contentsOfDirectory(atPath: baseDir)
                .filter { $0.hasPrefix("Backup_") }
                .sorted { $0 > $1 }
            
            var backups: [BackupInfo] = []
            
            for dirName in backupDirs {
                let backupPath = "\(baseDir)/\(dirName)"
                var backup = BackupInfo(
                    path: backupPath,
                    name: dirName,
                    date: parseDateFromBackupName(dirName) ?? Date()
                )
                
                backup.apps = await scanAppsInBackup(at: backupPath)
                
                if !backup.apps.isEmpty {
                    backups.append(backup)
                }
            }
            
            return backups
        } catch {
            logger.error("Failed to scan backups: \(error)")
            return []
        }
    }
    
    // Scan apps in a specific backup
    func scanAppsInBackup(at path: String) async -> [BackupAppInfo] {
        let fileManager = FileManager.default
        var apps: [BackupAppInfo] = []
        
        do {
            let appDirs = try fileManager.contentsOfDirectory(atPath: path)
                .filter { !$0.hasPrefix(".") }
            
            for appDir in appDirs {
                let appPath = "\(path)/\(appDir)"
                let configPath = "\(appPath)/app_config.json"
                
                if fileManager.fileExists(atPath: configPath) {
                    do {
                        let configData = try Data(contentsOf: URL(fileURLWithPath: configPath))
                        let appConfig = try JSONDecoder().decode(AppConfig.self, from: configData)
                        
                        let isInstalled = await fileOps.checkIfAppInstalled(bundleId: appConfig.bundleId)
                        
                        let backupApp = BackupAppInfo(
                            name: appConfig.name,
                            path: appPath,
                            bundleId: appConfig.bundleId,
                            configPaths: appConfig.configPaths,
                            isCurrentlyInstalled: isInstalled,
                            isSelected: false,
                            category: appConfig.category
                        )
                        
                        apps.append(backupApp)
                    } catch {
                        logger.error("Failed to read app config for \(appDir): \(error)")
                    }
                }
            }
        } catch {
            logger.error("Failed to scan apps in backup: \(error)")
        }
        
        return apps
    }
    
    private func parseDateFromBackupName(_ name: String) -> Date? {
        let dateString = name.replacingOccurrences(of: "Backup_", with: "")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-M-d, h-mm a"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.date(from: dateString)
    }
}
