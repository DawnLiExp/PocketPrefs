import Foundation
import Testing
@testable import PocketPrefs

@Suite("恢复筛选与选择")
@MainActor
struct RestoreListViewModelTests {
    @Test("筛选全选与取消只影响可见项，并保留隐藏勾选")
    func scopedSelection() throws {
        let temp = try TempDirectory()
        defer { temp.cleanup() }
        let (coordinator, model) = makeSetup(in: temp.url)
        model.searchText = "Beta"
        model.toggleSelectAll()
        model.searchText = "Alpha"
        #expect(model.cachedSelectedCount == 0)
        #expect(model.cachedTotalCount == 1)
        #expect(model.cachedOverallSelectedCount == 1)
        model.toggleSelectAll()
        #expect(model.cachedAllSelected)
        #expect(model.cachedOverallSelectedCount == 2)
        #expect(Set(coordinator.currentSelectedBackup!.apps.filter(\.isSelected).map(\.name)) == ["Alpha", "Beta"])
        model.toggleSelectAll()
        #expect(model.cachedOverallSelectedCount == 1)
        #expect(coordinator.currentSelectedBackup?.apps.first(where: { $0.name == "Beta" })?.isSelected == true)
        model.searchText = ""
        #expect(model.cachedTotalCount == 3)
        #expect(model.cachedSelectedCount == 1)
        #expect(!model.cachedAllSelected)
    }

    @Test("空结果全选不改变隐藏勾选；bundle ID 搜索与列表一致")
    func emptyAndBundleSearch() throws {
        let temp = try TempDirectory()
        defer { temp.cleanup() }
        let (coordinator, model) = makeSetup(in: temp.url)
        model.toggleSelectAll()
        model.searchText = "missing"
        #expect(model.cachedTotalCount == 0)
        #expect(!model.cachedAllSelected)
        model.toggleSelectAll()
        #expect(model.cachedOverallSelectedCount == 3)
        model.searchText = "COM.TEST.ALPHA"
        #expect(model.filteredApps.map(\.name) == ["Alpha"])
        #expect(model.cachedSelectedCount == 1)
        let mainModel = MainViewModel(coordinator: coordinator)
        let detail = DetailViewModel(coordinator: coordinator, mainViewModel: mainModel)
        #expect(detail.selectedRestoreAppsCount == 3)
    }

    @Test("切换备份即时更新筛选计数和总数")
    func switchBackup() throws {
        let temp = try TempDirectory()
        defer { temp.cleanup() }
        let (coordinator, model) = makeSetup(in: temp.url)
        model.toggleSelectAll()
        let other = BackupInfo(path: "/tmp/other", name: "Other", date: .now, apps: [.make(name: "Delta")])
        model.selectBackup(other)
        #expect(coordinator.currentSelectedBackup?.id == other.id)
        #expect(model.cachedTotalCount == 1)
        #expect(model.cachedSelectedCount == 0)
        #expect(model.cachedOverallSelectedCount == 0)
    }

    private func makeSetup(in directory: URL) -> (MainCoordinator, RestoreListViewModel) {
        let backup = BackupInfo(path: directory.appending(path: "backup").path, name: "Backup", date: .now,
                                apps: ["Alpha", "Beta", "Gamma"].map { .make(name: $0) })
        let coordinator = MainCoordinator(backups: [backup], userStore: UserConfigStore(storageURL: directory.appending(path: "apps.json")))
        let model = RestoreListViewModel(coordinator: coordinator)
        model.onAppear()
        return (coordinator, model)
    }
}
