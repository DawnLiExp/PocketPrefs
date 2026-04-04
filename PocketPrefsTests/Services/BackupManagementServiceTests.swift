//
//  BackupManagementServiceTests.swift
//  PocketPrefsTests
//
//  All tests operate on temporary directories and never touch real backup storage.
//  mergeBackups uses the injected baseDir parameter added in Phase 3.
//

import Foundation
import Testing
@testable import PocketPrefs

@Suite("BackupManagementService 单元测试")
struct BackupManagementServiceTests {

    let service = BackupManagementService()

    // MARK: - Fixture Builders

    /// Creates a backup directory tree under `base` and returns a matching `BackupInfo`.
    /// Each app entry produces a subdirectory containing a `marker.txt` for result verification.
    /// Note: does NOT write `app_config.json`; use `makeValidBackupFixture` when
    /// `scanAppsInBackup`-based cleanup logic must recognize the app as valid.
    private func makeBackupFixture(
        in base: URL,
        name: String,
        date: Date,
        apps: [(name: String, bundleId: String, marker: String)]
    ) throws -> BackupInfo {
        let backupURL = base.appending(path: name)
        try FileManager.default.createDirectory(at: backupURL, withIntermediateDirectories: true)

        var backupApps: [BackupAppInfo] = []
        for app in apps {
            let appURL = backupURL.appending(path: app.name)
            try FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)
            try app.marker.write(
                to: appURL.appending(path: "marker.txt"),
                atomically: true,
                encoding: .utf8
            )
            backupApps.append(BackupAppInfo(
                name: app.name,
                path: appURL.path,
                bundleId: app.bundleId,
                configPaths: [],
                isCurrentlyInstalled: true,
                isSelected: false,
                category: .custom
            ))
        }

        var info = BackupInfo(path: backupURL.path, name: name, date: date)
        info.apps = backupApps
        return info
    }

    /// Creates a backup directory tree whose app subdirectories contain a valid `app_config.json`.
    /// This makes `BackupService.scanAppsInBackup` recognize them as valid app backups,
    /// which is required for `cleanupBackupDirectoryIfNeeded` to behave correctly.
    private func makeValidBackupFixture(
        in base: URL,
        name: String,
        date: Date,
        apps: [(name: String, bundleId: String)]
    ) throws -> BackupInfo {
        let backupURL = base.appending(path: name)
        try FileManager.default.createDirectory(at: backupURL, withIntermediateDirectories: true)

        var backupApps: [BackupAppInfo] = []
        for app in apps {
            let appURL = backupURL.appending(path: app.name)
            try FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)

            // Write a minimal app_config.json so scanAppsInBackup treats this as a valid backup
            let config = AppConfig(
                name: app.name,
                bundleId: app.bundleId,
                configPaths: [],
                category: .custom,
                isUserAdded: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: appURL.appending(path: "app_config.json"))

            backupApps.append(BackupAppInfo(
                name: app.name,
                path: appURL.path,
                bundleId: app.bundleId,
                configPaths: [],
                isCurrentlyInstalled: false,
                isSelected: false,
                category: .custom
            ))
        }

        var info = BackupInfo(path: backupURL.path, name: name, date: date)
        info.apps = backupApps
        return info
    }

    // MARK: - mergeBackups

    @Test("mergeBackups：相同 bundleId 保留较新版本（newest-wins）")
    func mergeNewestWins() async throws {
        let tempDir = try TempDirectory()
        defer { tempDir.cleanup() }

        let older = try makeBackupFixture(
            in: tempDir.url,
            name: "Backup_2025-01-01_10-00-00",
            date: .distantPast,
            apps: [(name: "SomeApp", bundleId: "com.some.app", marker: "older")]
        )
        let newer = try makeBackupFixture(
            in: tempDir.url,
            name: "Backup_2025-06-01_10-00-00",
            date: .now,
            apps: [(name: "SomeApp", bundleId: "com.some.app", marker: "newer")]
        )

        // Array is intentionally [older, newer] — merge must sort by date, not input order
        let mergedPath = try await service.mergeBackups([older, newer], baseDir: tempDir.url.path)

        let markerURL = URL(filePath: mergedPath)
            .appending(path: "SomeApp/marker.txt")
        let content = try String(contentsOf: markerURL, encoding: .utf8)
        #expect(content == "newer")
    }

    @Test("mergeBackups：不同 bundleId 全部保留在合并目录中")
    func mergeDifferentBundleIds() async throws {
        let tempDir = try TempDirectory()
        defer { tempDir.cleanup() }

        let b1 = try makeBackupFixture(
            in: tempDir.url,
            name: "Backup_2025-01-01_10-00-00",
            date: .distantPast,
            apps: [(name: "AppA", bundleId: "com.app.a", marker: "a")]
        )
        let b2 = try makeBackupFixture(
            in: tempDir.url,
            name: "Backup_2025-06-01_10-00-00",
            date: .now,
            apps: [(name: "AppB", bundleId: "com.app.b", marker: "b")]
        )

        let mergedPath = try await service.mergeBackups([b1, b2], baseDir: tempDir.url.path)

        let contents = try FileManager.default.contentsOfDirectory(atPath: mergedPath)
        #expect(contents.contains("AppA"))
        #expect(contents.contains("AppB"))
    }

    @Test("mergeBackups：新目录创建于传入的 baseDir 下")
    func mergeCreatesUnderBaseDir() async throws {
        let tempDir = try TempDirectory()
        defer { tempDir.cleanup() }

        let b1 = try makeBackupFixture(
            in: tempDir.url, name: "Backup_2025-01-01_10-00-00", date: .distantPast,
            apps: [(name: "App1", bundleId: "com.app.1", marker: "x")]
        )
        let b2 = try makeBackupFixture(
            in: tempDir.url, name: "Backup_2025-06-01_10-00-00", date: .now,
            apps: [(name: "App2", bundleId: "com.app.2", marker: "y")]
        )

        let mergedPath = try await service.mergeBackups([b1, b2], baseDir: tempDir.url.path)

        let mergedParent = URL(filePath: mergedPath).deletingLastPathComponent().path
        #expect(mergedParent == tempDir.url.path)
        #expect(FileManager.default.fileExists(atPath: mergedPath))
    }

    @Test("mergeBackups：原始备份目录不被删除")
    func mergePreservesOriginals() async throws {
        let tempDir = try TempDirectory()
        defer { tempDir.cleanup() }

        let older = try makeBackupFixture(
            in: tempDir.url, name: "Backup_2025-01-01_10-00-00", date: .distantPast,
            apps: [(name: "SomeApp", bundleId: "com.some.app", marker: "older")]
        )
        let newer = try makeBackupFixture(
            in: tempDir.url, name: "Backup_2025-06-01_10-00-00", date: .now,
            apps: [(name: "SomeApp", bundleId: "com.some.app", marker: "newer")]
        )

        _ = try await service.mergeBackups([older, newer], baseDir: tempDir.url.path)

        #expect(FileManager.default.fileExists(atPath: older.path))
        #expect(FileManager.default.fileExists(atPath: newer.path))
    }

    // MARK: - deleteBackup

    @Test("deleteBackup：目录被成功删除")
    func deleteBackupSuccess() async throws {
        let tempDir = try TempDirectory()
        defer { tempDir.cleanup() }

        let backupURL = tempDir.url.appending(path: "TestBackup")
        try FileManager.default.createDirectory(at: backupURL, withIntermediateDirectories: true)
        let backup = BackupInfo(path: backupURL.path, name: "TestBackup", date: .now)

        try await service.deleteBackup(backup)

        #expect(!FileManager.default.fileExists(atPath: backupURL.path))
    }

    @Test("deleteBackup：路径不存在时抛出错误")
    func deleteNonExistentBackup() async {
        let backup = BackupInfo(
            path: "/nonexistent/ghost-\(UUID().uuidString)",
            name: "Ghost",
            date: .now
        )
        await #expect(throws: (any Error).self) {
            try await service.deleteBackup(backup)
        }
    }

    // MARK: - deleteAppFromBackup

    @Test("deleteAppFromBackup：app 子目录被删除，父备份目录保留")
    func deleteAppFromBackup() async throws {
        let tempDir = try TempDirectory()
        defer { tempDir.cleanup() }

        let backupURL = tempDir.url.appending(path: "TestBackup")
        let appURL    = backupURL.appending(path: "SomeApp")
        try FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)

        let app = BackupAppInfo(
            name: "SomeApp",
            path: appURL.path,
            bundleId: "com.some.app",
            configPaths: [],
            isCurrentlyInstalled: true,
            isSelected: false,
            category: .custom
        )

        try await service.deleteAppFromBackup(app)

        #expect(!FileManager.default.fileExists(atPath: appURL.path))
        #expect(FileManager.default.fileExists(atPath: backupURL.path))
    }

    // MARK: - deleteAppsFromBackup (high-level, with auto-cleanup)

    @Test("deleteAppsFromBackup：删除最后一个 app 后，父备份目录被删除")
    func deleteAppsLastApp_parentDeleted() async throws {
        let tempDir = try TempDirectory()
        defer { tempDir.cleanup() }

        let backup = try makeValidBackupFixture(
            in: tempDir.url,
            name: "Backup_2025-01-01_10-00-00",
            date: .now,
            apps: [(name: "OnlyApp", bundleId: "com.only.app")]
        )

        let outcome = await service.deleteAppsFromBackup(backup.apps, in: backup)

        #expect(outcome.deletedCount == 1)
        #expect(outcome.failedApps.isEmpty)
        #expect(outcome.parentBackupDeleted)
        #expect(!FileManager.default.fileExists(atPath: backup.path))
    }

    @Test("deleteAppsFromBackup：删除部分 app，剩余有效 app 时父目录保留")
    func deleteAppsPartial_parentPreserved() async throws {
        let tempDir = try TempDirectory()
        defer { tempDir.cleanup() }

        let backup = try makeValidBackupFixture(
            in: tempDir.url,
            name: "Backup_2025-01-01_10-00-00",
            date: .now,
            apps: [
                (name: "AppA", bundleId: "com.app.a"),
                (name: "AppB", bundleId: "com.app.b")
            ]
        )

        // Delete only AppA; AppB remains
        let toDelete = backup.apps.filter { $0.name == "AppA" }
        let outcome = await service.deleteAppsFromBackup(toDelete, in: backup)

        #expect(outcome.deletedCount == 1)
        #expect(!outcome.parentBackupDeleted)
        #expect(FileManager.default.fileExists(atPath: backup.path))
        // AppB's directory and its app_config.json must still exist
        let appBPath = URL(fileURLWithPath: backup.path).appending(path: "AppB/app_config.json").path
        #expect(FileManager.default.fileExists(atPath: appBPath))
    }

    @Test("deleteAppsFromBackup：父目录仅含无效子目录时，父备份目录也被删除")
    func deleteAppsOrphanDirsOnly_parentDeleted() async throws {
        let tempDir = try TempDirectory()
        defer { tempDir.cleanup() }

        // One valid app + one orphan directory (no app_config.json)
        let backup = try makeValidBackupFixture(
            in: tempDir.url,
            name: "Backup_2025-01-01_10-00-00",
            date: .now,
            apps: [(name: "RealApp", bundleId: "com.real.app")]
        )

        // Create an orphan subdirectory with no app_config.json
        let orphanURL = URL(fileURLWithPath: backup.path).appending(path: "OrphanDir")
        try FileManager.default.createDirectory(at: orphanURL, withIntermediateDirectories: true)
        try "junk".write(to: orphanURL.appending(path: "junk.txt"), atomically: true, encoding: .utf8)

        // Delete the only valid app; orphan dir remains but has no app_config.json
        let outcome = await service.deleteAppsFromBackup(backup.apps, in: backup)

        #expect(outcome.parentBackupDeleted)
        #expect(!FileManager.default.fileExists(atPath: backup.path))
    }

    @Test("cleanupBackupDirectoryIfNeeded：父目录不存在时幂等返回 false")
    func cleanupNonExistentParent_idempotent() async {
        let ghostPath = "/tmp/nonexistent-backup-\(UUID().uuidString)"
        let backup = BackupInfo(path: ghostPath, name: "GhostBackup", date: .now)

        let deleted = await service.cleanupBackupDirectoryIfNeeded(backup)

        // Directory never existed; no error and returns false
        #expect(!deleted)
    }
}
