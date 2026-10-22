import Foundation
import Testing
@testable import PocketPrefs

@Suite("操作结果与生命周期")
@MainActor
struct OperationResultTests {
    @Test("成功、部分失败、全部失败、零处理分类与原因")
    func classifyResults() {
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Read denied"])
        let success = OperationSummary(backup: BackupResult(successCount: 2, failedApps: [], totalProcessed: 2))
        let partial = OperationSummary(backup: BackupResult(successCount: 1, failedApps: [("Beta", error)], totalProcessed: 2))
        let failure = OperationSummary(restore: RestoreResult(successCount: 0, failedApps: [("Beta", error)], totalProcessed: 1))
        let empty = OperationSummary(restore: RestoreResult(successCount: 0, failedApps: [], totalProcessed: 0))
        #expect(success.status == .success)
        #expect(partial.status == .partialFailure)
        #expect(failure.status == .failure)
        #expect(empty.status == .notPerformed)
        #expect(partial.failures.first?.name == "Beta")
        #expect(partial.failures.first?.reason == "Read denied")
    }

    @Test("请求时固定选择；重复启动被拒绝；结果保留至完成")
    func backupLifecycle() async throws {
        let temp = try TempDirectory()
        defer { temp.cleanup() }
        var app = AppConfig.makeCustom(name: "Alpha")
        app.isSelected = true
        let coordinator = MainCoordinator(apps: [app], backups: [], userStore: UserConfigStore(storageURL: temp.url.appending(path: "apps.json")))
        let gate = OperationGate()
        var invocations = 0
        var capturedSelection = false
        let model = MainViewModel(coordinator: coordinator, backupOperation: { apps, _, progress in
            invocations += 1
            capturedSelection = apps.first?.isSelected == true
            await progress(ProgressUpdate(fraction: 0.5, message: "Working"))
            await gate.suspend()
            return BackupResult(successCount: 1, failedApps: [], totalProcessed: 1)
        })
        model.requestBackup()
        #expect(model.isProcessing)
        coordinator.deselectAll()
        model.requestBackup()
        await gate.waitUntilStarted()
        #expect(capturedSelection)
        #expect(invocations == 1)
        model.dismissOperationResult()
        #expect(model.isProcessing)
        gate.resume()
        await model.waitForOperation()
        #expect(!model.isProcessing)
        #expect(model.currentProgress == 0)
        #expect(model.statusMessageHistory.isEmpty)
        #expect(model.operationResult?.status == .success)
        model.requestBackup()
        #expect(invocations == 1)
        model.dismissOperationResult()
        #expect(model.operationResult == nil)
    }

    @Test("恢复设置与备份选择按请求快照执行；窗口结果相互独立")
    func restoreSnapshotAndWindowIsolation() async throws {
        let temp = try TempDirectory()
        defer { temp.cleanup() }
        var app = BackupAppInfo.make(name: "Alpha")
        app.isSelected = true
        let backup = BackupInfo(path: temp.url.path, name: "Backup", date: .now, apps: [app])
        let coordinator = MainCoordinator(backups: [backup], userStore: UserConfigStore(storageURL: temp.url.appending(path: "apps.json")))
        let preference = RestorePreference()
        var capturedPreference = true
        var capturedSelectedCount = 0
        let model = MainViewModel(coordinator: coordinator, restoreOperation: { value, createBackup, _ in
            capturedPreference = createBackup
            capturedSelectedCount = value.apps.count(where: \.isSelected)
            return RestoreResult(successCount: 1, failedApps: [], totalProcessed: 1)
        }, restoreBackupPreference: { preference.value })
        let otherWindow = MainViewModel(coordinator: coordinator)
        model.requestRestore()
        preference.value = true
        coordinator.deselectAllRestoreApps()
        await model.waitForOperation()
        #expect(!capturedPreference)
        #expect(capturedSelectedCount == 1)
        #expect(model.operationResult?.kind == .restore)
        #expect(otherWindow.operationResult == nil)
        #expect(!otherWindow.isProcessing)
    }

    @Test("没有有效备份时显示未执行，不能显示成功")
    func missingBackup() throws {
        let temp = try TempDirectory()
        defer { temp.cleanup() }
        let coordinator = MainCoordinator(backups: [], userStore: UserConfigStore(storageURL: temp.url.appending(path: "apps.json")))
        let model = MainViewModel(coordinator: coordinator)
        model.requestRestore()
        #expect(model.operationResult?.status == .notPerformed)
        #expect(model.operationResult?.notice?.isEmpty == false)
        #expect(!model.isProcessing)
    }
}

@MainActor
private final class RestorePreference {
    var value = false
}

@MainActor
private final class OperationGate {
    private var operation: CheckedContinuation<Void, Never>?
    private var waiter: CheckedContinuation<Void, Never>?
    private var started = false

    func suspend() async {
        await withCheckedContinuation { continuation in
            operation = continuation
            started = true
            waiter?.resume()
            waiter = nil
        }
    }

    func waitUntilStarted() async {
        guard !started else { return }
        await withCheckedContinuation { waiter = $0 }
    }

    func resume() {
        operation?.resume()
        operation = nil
    }
}
