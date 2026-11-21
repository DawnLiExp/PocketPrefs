import Foundation
import Testing
@testable import PocketPrefs

@Suite("恢复替换和原件保留")
struct RestoreReplacementTests {
    private func write(_ value: String, to file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(value.utf8).write(to: file)
    }

    private func restore(_ source: URL, to target: URL, keepPrevious: Bool) async -> RestoreResult {
        let folder = source.deletingLastPathComponent()
        let app = BackupAppInfo(
            name: "Editor", path: folder.path, bundleId: "test.editor", configPaths: [target.path],
            isCurrentlyInstalled: true, isSelected: true, category: .custom,
            backupEntries: [BackupEntry(originalPath: target.path, storedName: source.lastPathComponent)]
        )
        let backup = BackupInfo(path: folder.path, name: "Backup", date: .now, apps: [app])
        return await RestoreService().performRestore(backup: backup, createBackupBeforeRestore: keepPrevious)
    }

    @Test("复制目录中途遇到不可读文件，原目录和上次副本的内容均保留", arguments: [true, false])
    func copyFailureLeavesBothVersions(keepPrevious: Bool) async throws {
        let temp = try TempDirectory()
        defer { temp.cleanup() }
        let source = temp.url.appending(path: "archive/Settings")
        let denied = source.appending(path: "unreadable")
        try write("new", to: source.appending(path: "first"))
        try write("denied", to: denied)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: denied.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: denied.path) }
        let parent = temp.url.appending(path: "live")
        let current = parent.appending(path: "Settings")
        let previous = parent.appending(path: "Settings.pocketprefs_backup")
        try write("current", to: current.appending(path: "only"))
        try write("previous", to: previous.appending(path: "only"))

        let result = await restore(source, to: current, keepPrevious: keepPrevious)

        #expect(OperationSummary(restore: result).status == .failure)
        #expect(result.successCount == 0 && result.failedApps.count == 1)
        #expect(try Data(contentsOf: current.appending(path: "only")) == Data("current".utf8))
        #expect(try Data(contentsOf: previous.appending(path: "only")) == Data("previous".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: parent.path).sorted() == ["Settings", "Settings.pocketprefs_backup"])
    }

    @Test("完整目录替换按偏好轮换副本，两次恢复均保留正确内容", arguments: [true, false])
    func replaceDirectory(keepPrevious: Bool) async throws {
        let temp = try TempDirectory()
        defer { temp.cleanup() }
        let source = temp.url.appending(path: "archive/Settings")
        let current = temp.url.appending(path: "live/Settings")
        let previous = temp.url.appending(path: "live/Settings.pocketprefs_backup")
        try write("first restore", to: source.appending(path: "new"))
        try write("original", to: current.appending(path: "old"))
        try write("older", to: previous.appending(path: "older"))

        let first = await restore(source, to: current, keepPrevious: keepPrevious)
        #expect(first.isCompleteSuccess)
        #expect(try FileManager.default.contentsOfDirectory(atPath: current.path) == ["new"])
        #expect(try Data(contentsOf: current.appending(path: "new")) == Data("first restore".utf8))
        if keepPrevious {
            #expect(try Data(contentsOf: previous.appending(path: "old")) == Data("original".utf8))
        }
        try write("second restore", to: source.appending(path: "new"))
        let second = await restore(source, to: current, keepPrevious: keepPrevious)
        #expect(second.isCompleteSuccess)
        #expect(try Data(contentsOf: current.appending(path: "new")) == Data("second restore".utf8))
        let retained = previous.appending(path: keepPrevious ? "new" : "older")
        #expect(try Data(contentsOf: retained) == Data((keepPrevious ? "first restore" : "older").utf8))
    }

    @Test("已有副本不能轮换时，原文件回到原路径")
    func failedRotationRestoresOriginal() async throws {
        let temp = try TempDirectory()
        defer { temp.cleanup() }
        let source = temp.url.appending(path: "archive/prefs")
        let current = temp.url.appending(path: "live/prefs")
        let previous = temp.url.appending(path: "live/prefs.pocketprefs_backup")
        try write("new", to: source)
        try write("current", to: current)
        try write("previous", to: previous)
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: previous.path)
        defer { try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: previous.path) }

        let result = await restore(source, to: current, keepPrevious: true)

        #expect(OperationSummary(restore: result).status == .failure)
        #expect(try Data(contentsOf: current) == Data("current".utf8))
        #expect(try Data(contentsOf: previous) == Data("previous".utf8))
    }

    @Test("新用户目录首次恢复创建文件；之后源消失时保留当前内容")
    func restoreToNewLocation() async throws {
        let temp = try TempDirectory()
        defer { temp.cleanup() }
        let source = temp.url.appending(path: "backup/settings.json")
        let target = temp.url.appending(path: "new-account/config/settings.json")
        try write("saved bytes", to: source)
        let first = await restore(source, to: target, keepPrevious: true)
        #expect(first.isCompleteSuccess)
        #expect(try Data(contentsOf: target) == Data("saved bytes".utf8))
        #expect(!FileManager.default.fileExists(atPath: target.path + ".pocketprefs_backup"))

        try FileManager.default.removeItem(at: source)
        try write("later edit", to: target)
        let missing = await restore(source, to: target, keepPrevious: false)
        #expect(OperationSummary(restore: missing).status == .failure)
        #expect(try Data(contentsOf: target) == Data("later edit".utf8))
    }

    @Test("符号链接按链接本身替换，保留原来的悬空链接")
    func restoreSymbolicLink() async throws {
        let temp = try TempDirectory()
        defer { temp.cleanup() }
        let archive = temp.url.appending(path: "archive")
        try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
        let source = archive.appending(path: "config-link")
        let current = temp.url.appending(path: "config-link")
        try FileManager.default.createSymbolicLink(atPath: source.path, withDestinationPath: "new-referent")
        try FileManager.default.createSymbolicLink(atPath: current.path, withDestinationPath: "old-referent")
        let result = await restore(source, to: current, keepPrevious: true)
        #expect(result.isCompleteSuccess)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: current.path) == "new-referent")
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: current.path + ".pocketprefs_backup") == "old-referent")
    }
}
