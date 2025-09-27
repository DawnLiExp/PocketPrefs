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
    
    private enum Config {
        static let dateFormat = "yyyy-M-d, h-mm a"
        static let backupPrefix = "Backup_"
        static let configFileName = "app_config.json"
    }
    
    func performBackup(apps: [AppConfig]) async -> BackupResult {
        let selectedApps = apps.filter { $0.isSelected && $0.isInstalled }
        
        guard !selectedApps.isEmpty else {
            logger.error("No apps selected for backup")
            return BackupResult(successCount: 0, failedApps: [], totalProcessed: 0)
        }
        
        // Create backup directory
        let backupDir = createBackupPath()
        
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
        
        // Backup apps concurrently
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
    
    private func backupSingleApp(_ app: AppConfig, to backupDir: String) async -> Result<Void, Error> {
        let appBackupDir = "\(backupDir)/\(sanitizeName(app.name))"
        
        do {
            try await fileOps.createDirectory(at: appBackupDir)
            
            // Backup config files concurrently
            try await withThrowingTaskGroup(of: Void.self) { group in
                for path in app.configPaths {
                    group.addTask {
                        await self.backupConfigFile(
                            path: path,
                            to: appBackupDir
                        )
                    }
                }
                
                try await group.waitForAll()
            }
            
            // Save app configuration
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
    
    func scanBackups() async -> [BackupInfo] {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: baseDir) else {
            try? await fileOps.createDirectory(at: baseDir)
            return []
        }
        
        do {
            let backupDirs = try fileManager.contentsOfDirectory(atPath: baseDir)
                .filter { $0.hasPrefix(Config.backupPrefix) }
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
    
    func scanAppsInBackup(at path: String) async -> [BackupAppInfo] {
        let fileManager = FileManager.default
        var apps: [BackupAppInfo] = []
        
        do {
            let appDirs = try fileManager.contentsOfDirectory(atPath: path)
                .filter { !$0.hasPrefix(".") }
            
            for appDir in appDirs {
                if let backupApp = await loadBackupApp(
                    from: appDir,
                    at: path
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
                bundleId: appConfig.bundleId
            )
            
            return BackupAppInfo(
                name: appConfig.name,
                path: appPath,
                bundleId: appConfig.bundleId,
                configPaths: appConfig.configPaths,
                isCurrentlyInstalled: isInstalled,
                isSelected: false,
                category: appConfig.category
            )
        } catch {
            logger.error("Failed to read app config for \(appDir): \(error)")
            return nil
        }
    }
    
    private func createBackupPath() -> String {
        let timestamp = DateFormatter.localizedString(
            from: Date(),
            dateStyle: .short,
            timeStyle: .short
        )
        .replacingOccurrences(of: "/", with: "-")
        .replacingOccurrences(of: ":", with: "-")
        
        return "\(baseDir)/\(Config.backupPrefix)\(timestamp)"
    }
    
    private func sanitizeName(_ name: String) -> String {
        name.replacingOccurrences(of: " ", with: "_")
    }
    
    private func parseDateFromBackupName(_ name: String) -> Date? {
        let dateString = name.replacingOccurrences(of: Config.backupPrefix, with: "")
        let formatter = DateFormatter()
        formatter.dateFormat = Config.dateFormat
        formatter.locale = Locale(identifier: "en_US")
        return formatter.date(from: dateString)
    }
}
