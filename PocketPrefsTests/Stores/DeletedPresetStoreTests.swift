//
//  DeletedPresetStoreTests.swift
//  PocketPrefsTests
//

import Foundation
import Testing
@testable import PocketPrefs

@Suite("DeletedPresetStore 单元测试")
@MainActor
struct DeletedPresetStoreTests {

    // Each test creates its own isolated UserDefaults suite so tests are fully independent.
    private func makeStore() -> (store: DeletedPresetStore, defaults: UserDefaults, suiteName: String) {
        let suiteName = "com.me2.PocketPrefs.tests.\(UUID().uuidString)"
        let defaults  = UserDefaults(suiteName: suiteName)!
        let store     = DeletedPresetStore(defaults: defaults)
        return (store, defaults, suiteName)
    }

    // MARK: - Initial state

    @Test("初始状态 deletedBundleIds 为空")
    func initialEmpty() {
        let (store, _, suiteName) = makeStore()
        defer { UserDefaults.standard.removeSuite(named: suiteName) }
        #expect(store.deletedBundleIds.isEmpty)
    }

    // MARK: - markDeleted

    @Test("markDeleted 后包含该 bundleId")
    func markDeleted() {
        let (store, _, suiteName) = makeStore()
        defer { UserDefaults.standard.removeSuite(named: suiteName) }
        store.markDeleted("com.some.app")
        #expect(store.deletedBundleIds.contains("com.some.app"))
    }

    @Test("重复 markDeleted 无重复项（Set 语义）")
    func noDuplicates() {
        let (store, _, suiteName) = makeStore()
        defer { UserDefaults.standard.removeSuite(named: suiteName) }
        store.markDeleted("com.some.app")
        store.markDeleted("com.some.app")
        #expect(store.deletedBundleIds.count == 1)
    }

    @Test("多个不同 bundleId 均被记录")
    func multipleIds() {
        let (store, _, suiteName) = makeStore()
        defer { UserDefaults.standard.removeSuite(named: suiteName) }
        store.markDeleted("com.app.one")
        store.markDeleted("com.app.two")
        #expect(store.deletedBundleIds.count == 2)
        #expect(store.deletedBundleIds.contains("com.app.one"))
        #expect(store.deletedBundleIds.contains("com.app.two"))
    }

    // MARK: - Persistence

    @Test("持久化：新实例从同一 defaults 加载后仍包含已删除 bundleId")
    func persistence() {
        let (store, defaults, suiteName) = makeStore()
        defer { UserDefaults.standard.removeSuite(named: suiteName) }
        store.markDeleted("com.persisted.app")
        // Create a second instance with the same defaults — simulates app relaunch
        let store2 = DeletedPresetStore(defaults: defaults)
        #expect(store2.deletedBundleIds.contains("com.persisted.app"))
    }

    @Test("持久化：多个 bundleId 均能跨实例恢复")
    func persistenceMultiple() {
        let (store, defaults, suiteName) = makeStore()
        defer { UserDefaults.standard.removeSuite(named: suiteName) }
        store.markDeleted("com.app.alpha")
        store.markDeleted("com.app.beta")
        let store2 = DeletedPresetStore(defaults: defaults)
        #expect(store2.deletedBundleIds.contains("com.app.alpha"))
        #expect(store2.deletedBundleIds.contains("com.app.beta"))
        #expect(store2.deletedBundleIds.count == 2)
    }
}
