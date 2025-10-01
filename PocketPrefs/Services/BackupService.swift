//
//  BackupService.swift
//  PocketPrefs
//
//  Backup operations service with incremental backup support
//

import Foundation
import os.log

actor BackupService {
    private let logger = Logger(subsystem: "com.pocketprefs", category: "BackupService")
    private let fileOps = FileOperationService.shared
    private let baseDir = NSHomeDirectory() + "/Documents/PocketPrefsBackups"
    
    private enum Config {
        static let backupDateFormat = "yyyy-MM-dd_HH-mm-ss"
        static let backupPrefix = "Backup_"
        static let configFileName = "app_config.json"
    }
    
    func performBackup(apps: [AppConfig], incrementalBase: BackupInfo? = nil) async -> BackupResult {
        let selectedApps = apps.filter { $0.isSelected && $0.isInstalled }
        
        guard !selectedApps.isEmpty else {
            logger.error("No apps selected for backup")
            return BackupResult(successCount: 0, failedApps: [], totalProcessed: 0)
        }
        
        // Check if incremental mode is valid
        let isIncrementalValid = await validateIncrementalBase(incrementalBase)
        
        if isIncrementalValid, let baseBackup = incrementalBase {
            return await performIncrementalBackup(
                selectedApps: selectedApps,
                baseBackup: baseBackup,
            )
        } else {
            return await performRegularBackup(selectedApps: selectedApps)
        }
    }
    
    // MARK: - Regular Backup
    
    private func performRegularBackup(selectedApps: [AppConfig]) async -> BackupResult {
        let backupDir = createBackupPath()
        
        do {
            try await fileOps.createDirectory(at: backupDir)
            logger.info("Created backup directory: \(backupDir)")
        } catch {
            logger.error("Failed to create backup directory: \(error)")
            return BackupResult(
                successCount: 0,
                failedApps: selectedApps.map { ($0.name, error) },
                totalProcessed: selectedApps.count,
            )
        }
        
        return await backupApps(selectedApps, to: backupDir)
    }
    
    // MARK: - Incremental Backup
    
    private func performIncrementalBackup(
        selectedApps: [AppConfig],
        baseBackup: BackupInfo,
    ) async -> BackupResult {
        let backupDir = createBackupPath()
        
        do {
            try await fileOps.createDirectory(at: backupDir)
            logger.info("Created incremental backup directory: \(backupDir)")
        } catch {
            logger.error("Failed to create incremental backup directory: \(error)")
            return BackupResult(
                successCount: 0,
                failedApps: selectedApps.map { ($0.name, error) },
                totalProcessed: selectedApps.count,
            )
        }
        
        // Build selected app bundle IDs set for quick lookup
        let selectedBundleIds = Set(selectedApps.map(\.bundleId))
        
        // Copy unselected apps from base backup
        let copyResult = await copyUnselectedAppsFromBase(
            baseBackup: baseBackup,
            selectedBundleIds: selectedBundleIds,
            to: backupDir,
        )
        
        // Backup selected apps from current system
        let backupResult = await backupApps(selectedApps, to: backupDir)
        
        // Combine results
        let totalSuccess = copyResult.successCount + backupResult.successCount
        let totalFailed = copyResult.failedApps + backupResult.failedApps
        let totalProcessed = copyResult.totalProcessed + backupResult.totalProcessed
        
        logger.info("Incremental backup completed: \(totalSuccess) apps, \(totalFailed.count) failed")
        
        return BackupResult(
            successCount: totalSuccess,
            failedApps: totalFailed,
            totalProcessed: totalProcessed,
        )
    }
    
    private func copyUnselectedAppsFromBase(
        baseBackup: BackupInfo,
        selectedBundleIds: Set<String>,
        to destinationDir: String,
    ) async -> BackupResult {
        let baseApps = await scanAppsInBackup(at: baseBackup.path)
        let unselectedApps = baseApps.filter { !selectedBundleIds.contains($0.bundleId) }
        
        guard !unselectedApps.isEmpty else {
            return BackupResult(successCount: 0, failedApps: [], totalProcessed: 0)
        }
        
        var successCount = 0
        var failedApps: [(String, Error)] = []
        
        await withTaskGroup(of: (String, Result<Void, Error>).self) { group in
            for app in unselectedApps {
                group.addTask {
                    let result = await self.copyAppDirectory(
                        from: app.path,
                        to: destinationDir,
                        appName: app.name,
                    )
                    return (app.name, result)
                }
            }
            
            for await (appName, result) in group {
                switch result {
                case .success:
                    successCount += 1
                    logger.info("Copied from base: \(appName)")
                case .failure(let error):
                    failedApps.append((appName, error))
                    logger.error("Failed to copy from base \(appName): \(error)")
                }
            }
        }
        
        return BackupResult(
            successCount: successCount,
            failedApps: failedApps,
            totalProcessed: unselectedApps.count,
        )
    }
    
    private func copyAppDirectory(
        from sourcePath: String,
        to destinationBase: String,
        appName: String,
    ) async -> Result<Void, Error> {
        let fileManager = FileManager.default
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let destDirName = sanitizeName(appName)
        let destURL = URL(fileURLWithPath: destinationBase)
            .appendingPathComponent(destDirName)
        
        do {
            try fileManager.copyItem(at: sourceURL, to: destURL)
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    // MARK: - Common Backup Logic
    
    private func backupApps(_ apps: [AppConfig], to backupDir: String) async -> BackupResult {
        var successCount = 0
        var failedApps: [(String, Error)] = []
        
        await withTaskGroup(of: (String, Result<Void, Error>).self) { group in
            for app in apps {
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
            totalProcessed: apps.count,
        )
    }
    
    private func backupSingleApp(_ app: AppConfig, to backupDir: String) async -> Result<Void, Error> {
        let appBackupDir = "\(backupDir)/\(sanitizeName(app.name))"
        
        do {
            try await fileOps.createDirectory(at: appBackupDir)
            
            try await withThrowingTaskGroup(of: Void.self) { group in
                for path in app.configPaths {
                    group.addTask {
                        await self.backupConfigFile(
                            path: path,
                            to: appBackupDir,
                        )
                    }
                }
                
                try await group.waitForAll()
            }
            
            try await saveAppConfig(app, to: appBackupDir)
            
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    private func backupConfigFile(path: String, to destinationDir: String) async {
        let expandedPath = NSString(string: path).expandingTildeInPath
        
        if await fileOps.fileExists(at: expandedPath) {
            let fileName = URL(fileURLWithPath: expandedPath).lastPathComponent
            let destPath = "\(destinationDir)/\(fileName)"
            
            do {
                try await fileOps.copyFile(from: expandedPath, to: destPath)
            } catch {
                logger.warning("Failed to backup file \(path): \(error)")
            }
        }
    }
    
    private func saveAppConfig(_ app: AppConfig, to directory: String) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let configData = try encoder.encode(app)
        let configURL = URL(fileURLWithPath: "\(directory)/\(Config.configFileName)")
        try configData.write(to: configURL)
    }
    
    // MARK: - Validation
    
    private func validateIncrementalBase(_ baseBackup: BackupInfo?) async -> Bool {
        guard let baseBackup else { return false }
        
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: baseBackup.path)
    }
    
    // MARK: - Backup Scanning
    
    func scanBackups() async -> [BackupInfo] {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: baseDir) else {
            try? await fileOps.createDirectory(at: baseDir)
            return []
        }
        
        do {
            let backupDirs = try fileManager.contentsOfDirectory(atPath: baseDir)
                .filter { $0.hasPrefix(Config.backupPrefix) }
                .sorted(by: >)

            var backups: [BackupInfo] = []
            
            for dirName in backupDirs {
                let backupPath = "\(baseDir)/\(dirName)"
                
                guard let date = parseDateFromBackupName(dirName) else {
                    logger.warning("Skipping backup '\(dirName)' due to unparseable date format")
                    continue
                }

                var backup = BackupInfo(
                    path: backupPath,
                    name: dirName,
                    date: date,
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
    
    func scanAppsInBackup(at path: String) async -> [BackupAppInfo] {
        let fileManager = FileManager.default
        var apps: [BackupAppInfo] = []
        
        do {
            let appDirs = try fileManager.contentsOfDirectory(atPath: path)
                .filter { !$0.hasPrefix(".") }
            
            for appDir in appDirs {
                if let backupApp = await loadBackupApp(
                    from: appDir,
                    at: path,
                ) {
                    apps.append(backupApp)
                }
            }
        } catch {
            logger.error("Failed to scan apps in backup: \(error)")
        }
        
        return apps
    }
    
    private func loadBackupApp(from appDir: String, at basePath: String) async -> BackupAppInfo? {
        let appPath = "\(basePath)/\(appDir)"
        let configPath = "\(appPath)/\(Config.configFileName)"
        
        guard FileManager.default.fileExists(atPath: configPath) else {
            return nil
        }
        
        do {
            let configData = try Data(contentsOf: URL(fileURLWithPath: configPath))
            let appConfig = try JSONDecoder().decode(AppConfig.self, from: configData)
            
            let isInstalled = await fileOps.checkIfAppInstalled(
                bundleId: appConfig.bundleId,
            )
            
            return BackupAppInfo(
                name: appConfig.name,
                path: appPath,
                bundleId: appConfig.bundleId,
                configPaths: appConfig.configPaths,
                isCurrentlyInstalled: isInstalled,
                isSelected: false,
                category: appConfig.category,
            )
        } catch {
            logger.error("Failed to read app config for \(appDir): \(error)")
            return nil
        }
    }

    // MARK: - Helpers
    
    private func createBackupPath() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = Config.backupDateFormat
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let timestamp = formatter.string(from: Date())
        
        return "\(baseDir)/\(Config.backupPrefix)\(timestamp)"
    }
    
    private func sanitizeName(_ name: String) -> String {
        name.replacingOccurrences(of: " ", with: "_")
    }
    
    private func parseDateFromBackupName(_ name: String) -> Date? {
        let dateString = name.replacingOccurrences(of: Config.backupPrefix, with: "")
        
        let formatter = DateFormatter()
        formatter.dateFormat = Config.backupDateFormat
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        return formatter.date(from: dateString)
    }
}
