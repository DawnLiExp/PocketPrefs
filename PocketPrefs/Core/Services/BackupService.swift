//
//  BackupService.swift
//  PocketPrefs
//
//  Backup operations service with dynamic directory support
//

import Foundation
import os.log

actor BackupService {
    private let logger = Logger(subsystem: "com.me2.PocketPrefs", category: "BackupService")
    private let fileOps = FileOperationService.shared
    private let baseDirectory: URL?

    init(baseDirectory: URL? = nil) {
        self.baseDirectory = baseDirectory
    }
    
    enum Config {
        static let backupDateFormat = "yyyy-MM-dd_HH-mm-ss"
        static let backupPrefix = "Backup_"
    }
    
    /// Reusable date formatter for backup timestamps
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = Config.backupDateFormat
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    private func getBaseDirectory() async -> String {
        if let baseDirectory { return baseDirectory.path }
        return await PreferencesManager.shared.getBackupDirectory()
    }
    
    // MARK: - Public Interface
    
    /// Performs backup operation with optional incremental mode
    /// - Parameters:
    ///   - apps: Available applications for backup
    ///   - incrementalBase: Base backup for incremental mode (if valid)
    ///   - onProgress: Progress callback handler
    /// - Returns: Backup result with success/failure statistics
    func performBackup(
        apps: [AppConfig],
        incrementalBase: BackupInfo? = nil,
        onProgress: ProgressHandler? = nil,
    ) async -> BackupResult {
        let selectedApps = apps.filter { $0.isSelected && $0.isInstalled }
        
        guard !selectedApps.isEmpty else {
            logger.error("No apps selected for backup")
            return BackupResult(successCount: 0, failedApps: [], totalProcessed: 0)
        }
        
        await onProgress?(.idle)
        
        let isIncrementalValid = await validateIncrementalBase(incrementalBase)
        
        if isIncrementalValid, let baseBackup = incrementalBase {
            return await performIncrementalBackup(
                selectedApps: selectedApps,
                baseBackup: baseBackup,
                onProgress: onProgress,
            )
        } else {
            return await performRegularBackup(
                selectedApps: selectedApps,
                onProgress: onProgress,
            )
        }
    }
    
    // MARK: - Regular Backup
    
    private func performRegularBackup(
        selectedApps: [AppConfig],
        onProgress: ProgressHandler?,
    ) async -> BackupResult {
        let backupDir = await createBackupPath()
        
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
        
        return await backupApps(selectedApps, to: backupDir, onProgress: onProgress)
    }
    
    // MARK: - Incremental Backup
    
    private func performIncrementalBackup(
        selectedApps: [AppConfig],
        baseBackup: BackupInfo,
        onProgress: ProgressHandler?,
    ) async -> BackupResult {
        let backupDir = await createBackupPath()
        
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
        
        let selectedBundleIds = Set(selectedApps.map(\.bundleId))
        
        let copyResult = await copyUnselectedAppsFromBase(
            baseBackup: baseBackup,
            selectedBundleIds: selectedBundleIds,
            to: backupDir,
        )
        
        let backupResult = await backupApps(
            selectedApps,
            to: backupDir,
            onProgress: onProgress,
        )
        
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
    
    /// Copies unselected apps from base backup to maintain full state
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
                    do {
                        try await self.fileOps.copyArchivedApp(app, to: URL(fileURLWithPath: destinationDir))
                        return (app.name, .success(()))
                    } catch {
                        return (app.name, .failure(error))
                    }
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
    
    // MARK: - Common Backup Logic
    
    /// Backs up selected apps concurrently with progress reporting
    private func backupApps(
        _ apps: [AppConfig],
        to backupDir: String,
        onProgress: ProgressHandler?,
    ) async -> BackupResult {
        var successCount = 0
        var failedApps: [(String, Error)] = []
        let totalApps = apps.count
        var completedApps = 0
        
        await withTaskGroup(of: (String, Result<Void, Error>).self) { group in
            for app in apps {
                group.addTask {
                    let result = await self.backupSingleApp(app, to: backupDir)
                    return (app.name, result)
                }
            }
            
            for await (appName, result) in group {
                completedApps += 1
                
                switch result {
                case .success:
                    successCount += 1
                    logger.info("Successfully backed up: \(appName)")
                case .failure(let error):
                    failedApps.append((appName, error))
                    logger.error("Failed to backup \(appName): \(error)")
                }
                
                let progress = ProgressUpdate(
                    completed: completedApps,
                    total: totalApps,
                    message: String(localized: "Backup_Progress_Message", defaultValue: "Backing up \(appName)..."),
                )
                await onProgress?(progress)
            }
        }
        
        return BackupResult(
            successCount: successCount,
            failedApps: failedApps,
            totalProcessed: apps.count,
        )
    }
    
    private func backupSingleApp(_ app: AppConfig, to backupDir: String) async -> Result<Void, Error> {
        let directory = BackupManifest.directory(in: URL(fileURLWithPath: backupDir), bundleID: app.bundleId)
        let manager = FileManager.default
        do {
            // Never write into or clean up an app directory owned by a previous operation.
            try manager.createDirectory(at: directory, withIntermediateDirectories: false)
        } catch {
            return .failure(error)
        }

        var saved: [BackupEntry] = []
        var issues = ConfigurationFileIssues()
        var manifestWritten = false
        defer {
            if !manifestWritten { try? manager.removeItem(at: directory) }
        }
        for entry in BackupManifest.entries(for: app.configPaths) {
            let source = URL(fileURLWithPath: NSString(string: entry.originalPath).expandingTildeInPath)
            let destination = directory.appendingPathComponent(entry.storedName)
            do {
                try manager.copyItem(at: source, to: destination)
                saved.append(entry)
            } catch {
                // copyItem can leave an incomplete directory after a descendant fails.
                try? manager.removeItem(at: destination)
                if let error = error as? CocoaError, [.fileNoSuchFile, .fileReadNoSuchFile].contains(error.code) {
                    issues.reasons.append(String(localized: "Backup_Skipped_Missing_Path", defaultValue: "Skipped missing source: \(entry.originalPath)"))
                } else {
                    issues.record(error, at: entry.originalPath)
                }
            }
        }
        guard !saved.isEmpty else { return .failure(issues) }
        do {
            let manifest = BackupManifest(app: app, savedEntries: saved)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(manifest).write(to: directory.appendingPathComponent(BackupManifest.filename), options: .atomic)
            manifestWritten = true
        } catch {
            return .failure(error)
        }
        issues.completed = saved.count
        return issues.reasons.isEmpty ? .success(()) : .failure(issues)
    }

    // MARK: - Validation
    
    private func validateIncrementalBase(_ baseBackup: BackupInfo?) async -> Bool {
        guard let baseBackup else { return false }
        return FileManager.default.fileExists(atPath: baseBackup.path)
    }
    
    // MARK: - Backup Scanning
    
    /// Scans backup directory for existing backups
    func scanBackups() async -> [BackupInfo] {
        let baseDir = await getBaseDirectory()
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
                
                guard let date = parseBackupDate(from: dirName) else {
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
        let configPath = "\(appPath)/\(BackupManifest.filename)"
        
        guard FileManager.default.fileExists(atPath: configPath) else {
            return nil
        }
        
        do {
            let configData = try Data(contentsOf: URL(fileURLWithPath: configPath))
            let manifest = try JSONDecoder().decode(BackupManifest.self, from: configData)
            let appConfig = manifest.app

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
                backupEntries: manifest.entries,
            )
        } catch {
            logger.error("Failed to read app config for \(appDir): \(error)")
            return nil
        }
    }
    
    // MARK: - Helpers
    
    private func createBackupPath() async -> String {
        let baseDir = await getBaseDirectory()
        let timestamp = Self.dateFormatter.string(from: Date())
        return "\(baseDir)/\(Config.backupPrefix)\(timestamp)"
    }
    
    private func parseBackupDate(from name: String) -> Date? {
        let dateString = name.replacingOccurrences(of: Config.backupPrefix, with: "")
        return Self.dateFormatter.date(from: dateString)
    }
}
