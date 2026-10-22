//
//  DetailViewModelTests.swift
//  PocketPrefsTests
//
//  Regression tests for coordinator-derived detail state.
//

import Foundation
import Testing
@testable import PocketPrefs

@Suite("DetailViewModel 回归测试")
@MainActor
struct DetailViewModelTests {
    // MARK: - Backup Selection

    @Test("备份状态：全选后 hasValidBackupSelection 与 installed 集合一致")
    func backupSelectionDerivedFromCoordinatorApps() async {
        let (coordinator, _, detailViewModel) = await makeSetup()

        coordinator.deselectAll()
        #expect(!detailViewModel.hasValidBackupSelection)

        coordinator.selectAll()
        let hasInstalledApps = coordinator.currentApps.contains(where: { $0.isInstalled })
        #expect(detailViewModel.hasValidBackupSelection == hasInstalledApps)
    }

    // MARK: - Restore Selection

    @Test("恢复状态：备份切换后已选数量/未安装数量/按钮可用态即时更新")
    func restoreSelectionDerivedFromSelectedBackup() async {
        let (coordinator, _, detailViewModel) = await makeSetup()

        let partiallySelected = makeBackup(
            name: "Backup_Partial",
            apps: [
                makeRestoreApp(name: "AppA", isSelected: true, isInstalled: true),
                makeRestoreApp(name: "AppB", isSelected: true, isInstalled: false),
                makeRestoreApp(name: "AppC", isSelected: false, isInstalled: true),
            ]
        )
        coordinator.selectBackup(partiallySelected)

        #expect(detailViewModel.selectedBackup?.id == partiallySelected.id)
        #expect(detailViewModel.selectedRestoreAppsCount == 2)
        #expect(detailViewModel.uninstalledSelectedCount == 1)
        #expect(detailViewModel.hasSelectedRestoreApps)

        let allSelected = makeBackup(
            name: "Backup_All",
            apps: [
                makeRestoreApp(name: "AppA", isSelected: true, isInstalled: true),
                makeRestoreApp(name: "AppB", isSelected: true, isInstalled: true),
                makeRestoreApp(name: "AppC", isSelected: true, isInstalled: false),
            ]
        )
        coordinator.selectBackup(allSelected)

        #expect(detailViewModel.selectedBackup?.id == allSelected.id)
        #expect(detailViewModel.selectedRestoreAppsCount == 3)
        #expect(detailViewModel.uninstalledSelectedCount == 1)
        #expect(detailViewModel.hasSelectedRestoreApps)

        let noneSelected = makeBackup(
            name: "Backup_None",
            apps: [
                makeRestoreApp(name: "AppA", isSelected: false, isInstalled: true),
                makeRestoreApp(name: "AppB", isSelected: false, isInstalled: false),
            ]
        )
        coordinator.selectBackup(noneSelected)

        #expect(detailViewModel.selectedBackup?.id == noneSelected.id)
        #expect(detailViewModel.selectedRestoreAppsCount == 0)
        #expect(detailViewModel.uninstalledSelectedCount == 0)
        #expect(!detailViewModel.hasSelectedRestoreApps)
    }

    // MARK: - Helpers

    @Test("按 ID 获取详情会跟随名称、路径更新，删除后返回空")
    func selectedAppFollowsStoreChanges() async throws {
        let temp = try TempDirectory()
        defer { temp.cleanup() }
        let store = UserConfigStore(storageURL: temp.url.appending(path: "apps.json"))
        var app = AppConfig.makeCustom(name: "Alpha")
        store.addApp(app)
        let coordinator = MainCoordinator(apps: [app], backups: [], userStore: store)
        let selectedID = app.id
        #expect(coordinator.app(withID: selectedID)?.name == "Alpha")
        app.name = "Updated Alpha"
        app.configPaths = ["~/new-config"]
        store.updateApp(app)
        await coordinator.loadApps()
        #expect(coordinator.app(withID: selectedID)?.name == "Updated Alpha")
        #expect(coordinator.app(withID: selectedID)?.configPaths == ["~/new-config"])
        store.removeApps([selectedID])
        await coordinator.loadApps()
        #expect(coordinator.app(withID: selectedID) == nil)
        #expect(coordinator.app(withID: nil) == nil)
    }

    private func makeSetup() async -> (coordinator: MainCoordinator, mainViewModel: MainViewModel, detailViewModel: DetailViewModel) {
        let coordinator = MainCoordinator()
        let mainViewModel = MainViewModel(coordinator: coordinator)
        let detailViewModel = DetailViewModel(
            coordinator: coordinator,
            mainViewModel: mainViewModel
        )
        // IMPORTANT: settle initial async bootstrap to avoid startup races in assertions.
        await coordinator.loadApps()
        await coordinator.scanBackups()
        return (coordinator, mainViewModel, detailViewModel)
    }

    private func makeBackup(name: String, apps: [BackupAppInfo]) -> BackupInfo {
        var backup = BackupInfo(
            path: "/tmp/\(name)-\(UUID().uuidString)",
            name: name,
            date: .now
        )
        backup.apps = apps
        return backup
    }

    private func makeRestoreApp(name: String, isSelected: Bool, isInstalled: Bool) -> BackupAppInfo {
        BackupAppInfo(
            name: name,
            path: "/tmp/\(name)-\(UUID().uuidString)",
            bundleId: "com.test.\(name.lowercased())",
            configPaths: [],
            isCurrentlyInstalled: isInstalled,
            isSelected: isSelected,
            category: .custom
        )
    }
}
