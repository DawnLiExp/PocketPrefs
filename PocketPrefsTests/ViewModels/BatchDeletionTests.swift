import Foundation
import Testing
@testable import PocketPrefs

@Suite("批量删除结果")
@MainActor
struct BatchDeletionTests {
    @Test("备份删除：全部成功、部分失败、全部失败", arguments: [[], ["Beta"], ["Alpha", "Beta", "Gamma"]])
    func deleteBackups(failedNames: [String]) async throws {
        let temp = try TempDirectory()
        defer { temp.cleanup() }
        let fixture = try DeletionFixture(root: temp.url, appMode: false, failures: Set(failedNames))
        let model = BackupManagementViewModel(scanOperation: { fixture.backups }, deleteBackupOperation: { try fixture.deleteBackup($0) })
        await model.loadBackups()
        model.selectedBackupIds = Set(model.backups.map(\.id))
        model.batchDeleteSelectedBackups()
        let confirmation = try #require(model.pendingAlert)
        model.pendingAlert = nil
        confirmation.primaryAction()
        #expect(model.isDeleting)
        let snapshot = model.selectedBackupIds
        model.toggleBackupSelection(snapshot.first ?? "missing")
        #expect(model.selectedBackupIds == snapshot)
        model.batchDeleteSelectedBackups()
        #expect(model.pendingAlert == nil)
        await model.waitForPendingMutations()
        #expect(fixture.attempted.count == 3)
        #expect(Set(model.backups.map(\.name)) == Set(failedNames))
        #expect(model.selectedBackupIds == Set(model.backups.map(\.id)))
        #expect(!model.isDeleting)
        #expect(model.canRefresh)
        #expect((model.pendingAlert != nil) == !failedNames.isEmpty)
        for name in failedNames {
            #expect(model.pendingAlert?.message.contains(name) == true)
            #expect(model.pendingAlert?.message.contains("Permission denied") == true)
        }
    }

    @Test("应用备份删除：成功项取消选择，失败项保留", arguments: [[], ["Beta"], ["Alpha", "Beta", "Gamma"]])
    func deleteApps(failedNames: [String]) async throws {
        let temp = try TempDirectory()
        defer { temp.cleanup() }
        let fixture = try DeletionFixture(root: temp.url, appMode: true, failures: Set(failedNames))
        let model = BackupManagementViewModel(scanOperation: { fixture.backups }, deleteAppOperation: { try fixture.deleteApp($0) })
        await model.loadBackups()
        let original = try #require(model.detailBackup)
        model.selectedDetailAppIds = Set(original.apps.map(\.id))
        model.deleteSelectedDetailApps()
        let confirmation = try #require(model.pendingAlert)
        model.pendingAlert = nil
        confirmation.primaryAction()
        let snapshot = model.selectedDetailAppIds
        model.clearDetailSelection()
        #expect(model.selectedDetailAppIds == snapshot)
        await model.waitForPendingMutations()
        let remaining = model.detailBackup?.apps ?? []
        #expect(Set(remaining.map(\.name)) == Set(failedNames))
        #expect(model.selectedDetailAppIds == Set(remaining.map(\.id)))
        #expect(fixture.attempted.count == 3)
        #expect((model.pendingAlert != nil) == !failedNames.isEmpty)
        #expect(!model.isDeleting)
    }
}

@MainActor
private final class DeletionFixture {
    var backups: [BackupInfo] = []
    var attempted: [String] = []
    let failures: Set<String>

    init(root: URL, appMode: Bool, failures: Set<String>) throws {
        self.failures = failures
        let names = ["Alpha", "Beta", "Gamma"]
        if appMode {
            let directory = root.appending(path: "backup")
            let apps = try names.map { name in
                let path = directory.appending(path: name)
                try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
                return BackupAppInfo(name: name, path: path.path, bundleId: "test.\(name)", configPaths: [], isCurrentlyInstalled: false, isSelected: false, category: .custom)
            }
            backups = [BackupInfo(path: directory.path, name: "Backup", date: .now, apps: apps)]
        } else {
            backups = try names.map { name in
                let path = root.appending(path: name)
                try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
                return BackupInfo(path: path.path, name: name, date: .now)
            }
        }
    }

    func deleteBackup(_ backup: BackupInfo) throws {
        try delete(name: backup.name, path: backup.path)
        backups.removeAll { $0.id == backup.id }
    }

    func deleteApp(_ app: BackupAppInfo) throws {
        try delete(name: app.name, path: app.path)
        for index in backups.indices {
            backups[index].apps.removeAll { $0.id == app.id }
        }
        backups.removeAll { $0.apps.isEmpty }
    }

    private func delete(name: String, path: String) throws {
        attempted.append(name)
        if failures.contains(name) {
            throw NSError(domain: "test", code: 13, userInfo: [NSLocalizedDescriptionKey: "Permission denied"])
        }
        try FileManager.default.removeItem(atPath: path)
    }
}
