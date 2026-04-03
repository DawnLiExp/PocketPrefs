//
//  BackupManagementViewModelTests.swift
//  PocketPrefsTests
//
//  BackupManagementViewModel has no external dependencies in its initializer,
//  so it can be instantiated directly. Only pure computed properties and
//  synchronous selection logic are tested here.
//

import Foundation
import Testing
@testable import PocketPrefs

@Suite("BackupManagementViewModel 计算属性与选择逻辑")
@MainActor
struct BackupManagementViewModelTests {

    // MARK: - canMerge

    @Test("canMerge：选中 0 个时为 false")
    func canMergeZero() {
        let vm = BackupManagementViewModel()
        #expect(!vm.canMerge)
    }

    @Test("canMerge：选中 1 个时为 false")
    func canMergeOne() {
        let vm = BackupManagementViewModel()
        vm.selectedBackupIds.insert("/tmp/backup-a")
        #expect(!vm.canMerge)
    }

    @Test("canMerge：选中 2 个时为 true")
    func canMergeTwo() {
        let vm = BackupManagementViewModel()
        vm.selectedBackupIds.insert("/tmp/backup-a")
        vm.selectedBackupIds.insert("/tmp/backup-b")
        #expect(vm.canMerge)
    }

    @Test("canMerge：选中 3 个以上时为 true")
    func canMergeMany() {
        let vm = BackupManagementViewModel()
        vm.selectedBackupIds.insert("/tmp/backup-a")
        vm.selectedBackupIds.insert("/tmp/backup-b")
        vm.selectedBackupIds.insert("/tmp/backup-c")
        #expect(vm.canMerge)
    }

    // MARK: - canBatchDelete

    @Test("canBatchDelete：空时为 false")
    func canBatchDeleteEmpty() {
        let vm = BackupManagementViewModel()
        #expect(!vm.canBatchDelete)
    }

    @Test("canBatchDelete：非空时为 true")
    func canBatchDeleteNonEmpty() {
        let vm = BackupManagementViewModel()
        vm.selectedBackupIds.insert("/tmp/backup-a")
        #expect(vm.canBatchDelete)
    }

    // MARK: - selectedCount / selectedDetailCount

    @Test("selectedCount 与 selectedBackupIds.count 一致")
    func selectedCount() {
        let vm = BackupManagementViewModel()
        #expect(vm.selectedCount == 0)
        vm.selectedBackupIds.insert("/tmp/backup-a")
        vm.selectedBackupIds.insert("/tmp/backup-b")
        #expect(vm.selectedCount == 2)
    }

    @Test("selectedDetailCount 与 selectedDetailAppIds.count 一致")
    func selectedDetailCount() {
        let vm = BackupManagementViewModel()
        #expect(vm.selectedDetailCount == 0)
        vm.selectedDetailAppIds.insert("/tmp/backup-a/AppX")
        #expect(vm.selectedDetailCount == 1)
    }

    // MARK: - toggleBackupSelection

    @Test("toggleBackupSelection：未选中 id → 加入 selectedBackupIds")
    func toggleBackupSelectionAdd() {
        let vm = BackupManagementViewModel()
        let id = "/tmp/backup-toggle"
        vm.toggleBackupSelection(id)
        #expect(vm.selectedBackupIds.contains(id))
    }

    @Test("toggleBackupSelection：已选中 id → 从 selectedBackupIds 移除")
    func toggleBackupSelectionRemove() {
        let vm = BackupManagementViewModel()
        let id = "/tmp/backup-toggle"
        vm.toggleBackupSelection(id)
        vm.toggleBackupSelection(id)
        #expect(!vm.selectedBackupIds.contains(id))
    }

    // MARK: - toggleDetailAppSelection

    @Test("toggleDetailAppSelection：未选中 → 加入；已选中 → 移除")
    func toggleDetailAppSelection() {
        let vm = BackupManagementViewModel()
        let id = "/tmp/backup-a/AppX"
        vm.toggleDetailAppSelection(id)
        #expect(vm.selectedDetailAppIds.contains(id))
        vm.toggleDetailAppSelection(id)
        #expect(!vm.selectedDetailAppIds.contains(id))
    }

    // MARK: - clearDetailSelection

    @Test("clearDetailSelection：selectedDetailAppIds 清空")
    func clearDetailSelection() {
        let vm = BackupManagementViewModel()
        vm.selectedDetailAppIds.insert("/tmp/backup-a/App1")
        vm.selectedDetailAppIds.insert("/tmp/backup-a/App2")
        vm.clearDetailSelection()
        #expect(vm.selectedDetailAppIds.isEmpty)
    }

    // MARK: - selectDetailBackup

    @Test("selectDetailBackup：更新 detailBackup，重置 selectedDetailAppIds 和 pendingDeleteBackupId")
    func selectDetailBackup() {
        let vm = BackupManagementViewModel()
        // Pre-populate dirty state
        vm.selectedDetailAppIds.insert("/tmp/backup-a/AppX")
        vm.pendingDeleteBackupId = "/tmp/backup-pending"

        // BackupInfo.apps is empty so the internal Task (computeAppSizes) exits immediately
        let backup = BackupInfo(path: "/tmp/test-\(UUID().uuidString)", name: "TestBackup", date: .now)
        vm.selectDetailBackup(backup)

        #expect(vm.detailBackup == backup)
        #expect(vm.selectedDetailAppIds.isEmpty)
        #expect(vm.pendingDeleteBackupId == nil)
    }
}
