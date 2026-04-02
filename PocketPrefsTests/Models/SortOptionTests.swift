//
//  SortOptionTests.swift
//  PocketPrefsTests
//

import Testing
@testable import PocketPrefs
import Foundation

@Suite("SortOption 排序逻辑")
struct SortOptionTests {

    // MARK: - Fixtures

    private func makeApps() -> [AppConfig] {
        [
            .makePreset(name: "Zed"),
            .makePreset(name: "Alfred"),
            .makeCustom(name: "Warp", createdAt: .distantPast),
            .makeCustom(name: "Arc",  createdAt: .now),
        ]
    }

    // MARK: - AppConfig: nameAscending

    @Test("nameAscending 按大小写不敏感升序排列")
    func nameAscending() {
        let sorted = SortOption.nameAscending.apply(to: makeApps())
        let names = sorted.map(\.name)
        for i in 0 ..< names.count - 1 {
            #expect(names[i].localizedCaseInsensitiveCompare(names[i + 1]) != .orderedDescending)
        }
    }

    // MARK: - AppConfig: nameDescending

    @Test("nameDescending 按大小写不敏感降序排列")
    func nameDescending() {
        let sorted = SortOption.nameDescending.apply(to: makeApps())
        let names = sorted.map(\.name)
        for i in 0 ..< names.count - 1 {
            #expect(names[i].localizedCaseInsensitiveCompare(names[i + 1]) != .orderedAscending)
        }
    }

    // MARK: - AppConfig: dateAddedDescending

    @Test("dateAddedDescending 用户 app 全部排在前，内部按 createdAt 降序")
    func dateAddedDescending() {
        let sorted = SortOption.dateAddedDescending.apply(to: makeApps())
        let userPart   = sorted.filter(\.isUserAdded)
        let presetPart = sorted.filter { !$0.isUserAdded }

        // 自定义 app 全在前
        #expect(sorted.prefix(userPart.count).allSatisfy { $0.isUserAdded })
        // 自定义 app 内部按 createdAt 降序
        let dates = userPart.map(\.createdAt)
        #expect(dates == dates.sorted(by: >))
        // 预置 app 存在且在后
        #expect(!presetPart.isEmpty)
    }

    @Test("全为 preset 时 dateAddedDescending 保持原始顺序")
    func allPresetsKeepOrder() {
        let apps: [AppConfig] = [
            .makePreset(name: "Zed"),
            .makePreset(name: "Alfred"),
            .makePreset(name: "Warp"),
        ]
        let sorted = SortOption.dateAddedDescending.apply(to: apps)
        #expect(sorted.map(\.name) == ["Zed", "Alfred", "Warp"])
    }

    // MARK: - Edge cases: AppConfig

    @Test("空数组输入返回空数组（AppConfig）")
    func emptyAppConfig() {
        #expect(SortOption.nameAscending.apply(to: [] as [AppConfig]).isEmpty)
        #expect(SortOption.nameDescending.apply(to: [] as [AppConfig]).isEmpty)
        #expect(SortOption.dateAddedDescending.apply(to: [] as [AppConfig]).isEmpty)
    }

    @Test("单元素 AppConfig 数组原样返回")
    func singleElementAppConfig() {
        let apps = [AppConfig.makePreset(name: "Solo")]
        #expect(SortOption.nameAscending.apply(to: apps).count == 1)
        #expect(SortOption.nameDescending.apply(to: apps).count == 1)
        #expect(SortOption.dateAddedDescending.apply(to: apps).count == 1)
    }

    // MARK: - BackupAppInfo sorting

    @Test("BackupAppInfo dateAddedDescending 保持输入顺序")
    func backupAppInfoDateOrder() {
        let apps: [BackupAppInfo] = [.make(name: "Z"), .make(name: "A"), .make(name: "M")]
        let sorted = SortOption.dateAddedDescending.apply(to: apps)
        #expect(sorted.map(\.name) == ["Z", "A", "M"])
    }

    @Test("BackupAppInfo nameAscending 按大小写不敏感升序")
    func backupAppInfoNameAscending() {
        let apps: [BackupAppInfo] = [.make(name: "Z"), .make(name: "A"), .make(name: "M")]
        let sorted = SortOption.nameAscending.apply(to: apps)
        let names = sorted.map(\.name)
        for i in 0 ..< names.count - 1 {
            #expect(names[i].localizedCaseInsensitiveCompare(names[i + 1]) != .orderedDescending)
        }
    }

    @Test("BackupAppInfo nameDescending 按大小写不敏感降序")
    func backupAppInfoNameDescending() {
        let apps: [BackupAppInfo] = [.make(name: "Z"), .make(name: "A"), .make(name: "M")]
        let sorted = SortOption.nameDescending.apply(to: apps)
        let names = sorted.map(\.name)
        for i in 0 ..< names.count - 1 {
            #expect(names[i].localizedCaseInsensitiveCompare(names[i + 1]) != .orderedAscending)
        }
    }

    @Test("空数组输入返回空数组（BackupAppInfo）")
    func emptyBackupAppInfo() {
        #expect(SortOption.nameAscending.apply(to: [] as [BackupAppInfo]).isEmpty)
        #expect(SortOption.nameDescending.apply(to: [] as [BackupAppInfo]).isEmpty)
        #expect(SortOption.dateAddedDescending.apply(to: [] as [BackupAppInfo]).isEmpty)
    }

    @Test("单元素 BackupAppInfo 数组原样返回")
    func singleElementBackupAppInfo() {
        let apps = [BackupAppInfo.make(name: "Solo")]
        #expect(SortOption.nameAscending.apply(to: apps).count == 1)
        #expect(SortOption.nameDescending.apply(to: apps).count == 1)
        #expect(SortOption.dateAddedDescending.apply(to: apps).count == 1)
    }
}
