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

    // MARK: - Fixture Builder

    /// Creates a backup directory tree under `base` and returns a matching `BackupInfo`.
    /// Each app entry produces a subdirectory containing a `marker.txt` for result verification.
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
            let config = AppConfig(name: app.name, bundleId: app.bundleId, configPaths: ["~/marker.txt"])
            try JSONEncoder().encode(config).write(to: appURL.appending(path: BackupManifest.filename))
            backupApps.append(BackupAppInfo(
                name: app.name,
                path: appURL.path,
                bundleId: app.bundleId,
                configPaths: config.configPaths,
                isCurrentlyInstalled: true,
                isSelected: false,
                category: .custom
            ))
        }

        var info = BackupInfo(path: backupURL.path, name: name, date: date)
        info.apps = backupApps
        return info
    }

    /// Creates a valid backup app directory that can be discovered by `scanAppsInBackup`.
    private func makeValidBackupApp(
        in backupURL: URL,
        appName: String,
        bundleId: String
    ) throws -> BackupAppInfo {
        let appURL = backupURL.appending(path: appName)
        try FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)

        let config = AppConfig(
            name: appName,
            bundleId: bundleId,
            configPaths: ["~/Library/Preferences/\(bundleId).plist"],
            category: .custom,
            isUserAdded: true,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(config)
        try data.write(to: appURL.appending(path: BackupManifest.filename))

        return BackupAppInfo(
            name: appName,
            path: appURL.path,
            bundleId: bundleId,
            configPaths: config.configPaths,
            isCurrentlyInstalled: false,
            isSelected: false,
            category: .custom
        )
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

        let scanned = await BackupService().scanAppsInBackup(at: mergedPath)
        let winner = try #require(scanned.first { $0.bundleId == "com.some.app" })
        let markerURL = URL(fileURLWithPath: winner.path).appending(path: "marker.txt")
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
            apps: [(name: "AppA", bundleId: "com.app.b", marker: "b")]
        )

        let mergedPath = try await service.mergeBackups([b1, b2], baseDir: tempDir.url.path)

        let scanned = await BackupService().scanAppsInBackup(at: mergedPath)
        #expect(Set(scanned.map(\.bundleId)) == ["com.app.a", "com.app.b"])
        for app in scanned {
            let marker = URL(fileURLWithPath: app.path).appending(path: "marker.txt")
            #expect(try String(contentsOf: marker, encoding: .utf8) == (app.bundleId == "com.app.a" ? "a" : "b"))
        }
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

    @Test("deleteAppFromBackup：删除最后一个 app 后，父备份目录也会被清理")
    func deleteAppFromBackup() async throws {
        let tempDir = try TempDirectory()
        defer { tempDir.cleanup() }

        let backupURL = tempDir.url.appending(path: "TestBackup")
        try FileManager.default.createDirectory(at: backupURL, withIntermediateDirectories: true)
        let app = try makeValidBackupApp(in: backupURL, appName: "SomeApp", bundleId: "com.some.app")

        try await service.deleteAppFromBackup(app)

        #expect(!FileManager.default.fileExists(atPath: app.path))
        #expect(!FileManager.default.fileExists(atPath: backupURL.path))
    }

    @Test("删除最后一个可识别应用时，隐藏文件和不可识别的配置内容保留", arguments: [".note", "Damaged/prefs.json"])
    func deletionPreservesUnselectedContents(relativePath: String) async throws {
        let temp = try TempDirectory()
        defer { temp.cleanup() }
        let backup = temp.url.appending(path: "Backup")
        let selected = try makeValidBackupApp(in: backup, appName: "Selected", bundleId: "com.test.selected")
        let other = backup.appending(path: relativePath)
        try FileManager.default.createDirectory(at: other.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = Data("keep my configuration".utf8)
        try original.write(to: other)

        try await service.deleteAppFromBackup(selected)

        #expect(!FileManager.default.fileExists(atPath: selected.path))
        #expect(try Data(contentsOf: other) == original)
    }

    @Test("deleteAppFromBackup：备份内仍有其它 app 时，父备份目录保留")
    func deleteAppFromBackupKeepsParentWhenOtherAppsRemain() async throws {
        let tempDir = try TempDirectory()
        defer { tempDir.cleanup() }

        let backupURL = tempDir.url.appending(path: "TestBackupMulti")
        try FileManager.default.createDirectory(at: backupURL, withIntermediateDirectories: true)

        let appToDelete = try makeValidBackupApp(
            in: backupURL,
            appName: "AppToDelete",
            bundleId: "com.test.delete"
        )
        _ = try makeValidBackupApp(
            in: backupURL,
            appName: "AppToKeep",
            bundleId: "com.test.keep"
        )

        try await service.deleteAppFromBackup(appToDelete)

        #expect(!FileManager.default.fileExists(atPath: appToDelete.path))
        #expect(FileManager.default.fileExists(atPath: backupURL.path))
    }
}
