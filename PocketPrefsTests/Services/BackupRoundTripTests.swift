import Foundation
import Testing
@testable import PocketPrefs

@Suite("备份、扫描和恢复的磁盘内容")
struct BackupRoundTripTests {
    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    private func app(_ bundleID: String, paths: [URL]) -> AppConfig {
        AppConfig(name: "Editor", bundleId: bundleID, configPaths: paths.map(\.path), isSelected: true)
    }

    private func selected(_ backup: BackupInfo) -> BackupInfo {
        var copy = backup
        for index in copy.apps.indices { copy.apps[index].isSelected = true }
        return copy
    }

    @Test("同名应用、清单同名、自然后缀和大小写相近的原文件均能逐字节恢复")
    func conflictingNamesRoundTrip() async throws {
        let temp = try TempDirectory()
        defer { temp.cleanup() }
        let service = BackupService(baseDirectory: temp.url.appending(path: "archives"))
        let paths = ["one/prefs", "two/prefs", "three/prefs_2", "four/PREFS", "five/app_config.json", "six/prefs"]
            .map { temp.url.appending(path: $0) }
        for (i, url) in paths.enumerated() { try write("original \(i)", to: url) }
        let first = app("com.test.Editor", paths: Array(paths.dropLast()))
        let second = app("com.test.editor", paths: [paths[5]])

        let result = await service.performBackup(apps: [first, second])
        #expect(result.successCount == 2)
        let backups = await service.scanBackups()
        let backup = try #require(backups.first)
        #expect(Set(backup.apps.map(\.bundleId)) == [first.bundleId, second.bundleId])
        for archived in backup.apps {
            let expected = archived.bundleId == first.bundleId ? first : second
            let entries = try #require(archived.backupEntries)
            #expect(entries.map(\.originalPath) == expected.configPaths)
            for entry in entries {
                let stored = URL(fileURLWithPath: archived.path).appending(path: entry.storedName)
                #expect(try Data(contentsOf: stored) == Data(contentsOf: URL(fileURLWithPath: entry.originalPath)))
            }
        }
        for path in paths { try write("current", to: path) }
        let restored = await RestoreService().performRestore(backup: selected(backup))
        #expect(restored.successCount == 2)
        for (i, path) in paths.enumerated() {
            #expect(try Data(contentsOf: path) == Data("original \(i)".utf8))
        }
    }

    @Test("缺失和真实复制错误分别反馈，清单只包含保存成功的路径")
    func partialAndEmptyBackups() async throws {
        let temp = try TempDirectory()
        defer { temp.cleanup() }
        let good = temp.url.appending(path: "good.json")
        let missing = temp.url.appending(path: "absent.json")
        let unreadable = temp.url.appending(path: "unreadable.json")
        try write("saved", to: good)
        try write("denied", to: unreadable)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: unreadable.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: unreadable.path) }
        let service = BackupService(baseDirectory: temp.url.appending(path: "archives"))
        let result = await service.performBackup(apps: [
            app("partial", paths: [good, missing, unreadable]), app("missing", paths: [missing]), app("empty", paths: [])
        ])
        let summary = OperationSummary(backup: result)
        #expect(summary.status == .partialFailure)
        #expect(summary.successCount == 0 && summary.partialAppCount == 1)
        #expect(summary.failures.count == 3)
        let partial = try #require(summary.failures.first { $0.hasCopiedFiles })
        #expect(partial.reason.contains(missing.path))
        #expect(partial.reason.contains(unreadable.path))

        let backups = await service.scanBackups()
        let backup = try #require(backups.first)
        #expect(backup.apps.map(\.bundleId) == ["partial"])
        let archived = try #require(backup.apps.first)
        #expect(archived.configPaths == [good.path])
        #expect(try FileManager.default.contentsOfDirectory(atPath: archived.path).sorted() == ["app_config.json", "good.json"])
        try write("changed", to: good)
        try write("created later", to: missing)
        let restored = await RestoreService().performRestore(backup: selected(backup))
        #expect(restored.successCount == 1)
        #expect(try Data(contentsOf: good) == Data("saved".utf8))
        #expect(try Data(contentsOf: missing) == Data("created later".utf8))
    }

    @Test("映射的第二份同名配置缺失时，恢复保留对应目标并报告部分完成")
    func missingMappedFileNeverUsesItsSibling() async throws {
        let temp = try TempDirectory()
        defer { temp.cleanup() }
        let service = BackupService(baseDirectory: temp.url.appending(path: "archives"))
        let first = temp.url.appending(path: "one/settings")
        let second = temp.url.appending(path: "two/settings")
        try write("first", to: first)
        try write("second", to: second)
        _ = await service.performBackup(apps: [app("editor", paths: [first, second])])
        let backups = await service.scanBackups()
        let backup = try #require(backups.first)
        let archived = try #require(backup.apps.first)
        let removed = try #require(archived.backupEntries?.first { $0.originalPath == second.path })
        try FileManager.default.removeItem(at: URL(fileURLWithPath: archived.path).appending(path: removed.storedName))
        try write("current first", to: first)
        try write("current second", to: second)
        let result = await RestoreService().performRestore(backup: selected(backup))
        #expect(OperationSummary(restore: result).status == .partialFailure)
        #expect(result.failedApps.first?.error.localizedDescription.contains(second.path) == true)
        #expect(try Data(contentsOf: first) == Data("first".utf8))
        #expect(try Data(contentsOf: second) == Data("current second".utf8))
        #expect(!FileManager.default.fileExists(atPath: second.path + ".pocketprefs_backup"))
    }

    @Test("v1.1 备份逐项恢复可辨认的文件，重复原名和清单同名项保留目标",
          arguments: [["prefs"], ["prefs", "prefs"], ["app_config.json"], ["prefs", "prefs", "other"]])
    func restoreLegacy(names: [String]) async throws {
        let temp = try TempDirectory()
        defer { temp.cleanup() }
        let service = BackupService(baseDirectory: temp.url)
        let folder = temp.url.appending(path: "Backup_2025-01-01_10-00-00/Old Editor")
        let targets = names.enumerated().map { temp.url.appending(path: "live/\($0.offset)/\($0.element)") }
        for path in targets { try write("existing", to: path) }
        try write("legacy bytes", to: folder.appending(path: "prefs"))
        try write("other bytes", to: folder.appending(path: "other"))
        let legacy: [String: Any] = ["name": "Editor", "bundleId": "com.test.editor", "category": "Custom",
                                    "isUserAdded": true, "configPaths": targets.map(\.path)]
        try JSONSerialization.data(withJSONObject: legacy).write(to: folder.appending(path: "app_config.json"))
        let backups = await service.scanBackups()
        let snapshot = try #require(backups.first)
        #expect(snapshot.apps.first?.backupEntries == nil)
        let result = await RestoreService().performRestore(backup: selected(snapshot))
        let status: OperationSummary.Status = names == ["prefs"] ? .success : (names.contains("other") ? .partialFailure : .failure)
        #expect(OperationSummary(restore: result).status == status)
        for (path, name) in zip(targets, names) {
            let expected = name == "other" ? "other bytes" : (names == ["prefs"] ? "legacy bytes" : "existing")
            #expect(try Data(contentsOf: path) == Data(expected.utf8))
        }
    }

    @Test("增量备份保留同名的未选应用内容")
    func incrementalUsesBundleIdentity() async throws {
        let temp = try TempDirectory()
        defer { temp.cleanup() }
        let base = BackupService(baseDirectory: temp.url.appending(path: "base"))
        let incremental = BackupService(baseDirectory: temp.url.appending(path: "incremental"))
        let first = temp.url.appending(path: "A/settings")
        let second = temp.url.appending(path: "B/settings")
        try write("old A", to: first)
        try write("old B", to: second)
        let a = app("com.test.A", paths: [first])
        let b = app("com.test.B", paths: [second])
        _ = await base.performBackup(apps: [a, b])
        let bases = await base.scanBackups()
        let original = try #require(bases.first)
        try write("new A", to: first)
        try write("new B", to: second)
        let result = await incremental.performBackup(apps: [a], incrementalBase: original)
        #expect(result.successCount == 2)
        let backups = await incremental.scanBackups()
        let snapshot = try #require(backups.first)
        try write("overwritten A", to: first)
        let restored = await RestoreService().performRestore(backup: selected(snapshot))
        #expect(restored.successCount == 2)
        #expect(try Data(contentsOf: first) == Data("new A".utf8))
        #expect(try Data(contentsOf: second) == Data("old B".utf8))

        let archivedB = try #require(original.apps.first { $0.bundleId == b.bundleId })
        let entry = try #require(archivedB.backupEntries?.first)
        try FileManager.default.removeItem(at: URL(fileURLWithPath: archivedB.path).appending(path: entry.storedName))
        let retry = BackupService(baseDirectory: temp.url.appending(path: "other-incremental"))
        let incomplete = await retry.performBackup(apps: [a], incrementalBase: original)
        #expect(incomplete.successCount == 1 && incomplete.failedApps.count == 1)
        let retried = await retry.scanBackups()
        #expect(retried.first?.apps.map(\.bundleId) == [a.bundleId])
    }
}
