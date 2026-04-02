//
//  UserConfigStoreTests.swift
//  PocketPrefsTests
//
//  UserConfigStore is @MainActor @Observable; all test methods run on MainActor.
//  Each test creates an isolated store backed by a UUID-named temp JSON file.
//

import Foundation
import Testing
@testable import PocketPrefs

@Suite("UserConfigStore 单元测试")
@MainActor
struct UserConfigStoreTests {

    private func makeTempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "ucs-test-\(UUID().uuidString).json")
    }

    // MARK: - addApp

    @Test("addApp：customApps 包含新 app")
    func addAppContains() {
        let store = UserConfigStore(storageURL: makeTempURL())
        let app = AppConfig.makeCustom(name: "AddMe", bundleId: "com.test.addme")
        store.addApp(app)
        #expect(store.customApps.contains { $0.bundleId == "com.test.addme" })
    }

    @Test("addApp：isUserAdded 强制设为 true")
    func addAppSetsUserAdded() {
        let store = UserConfigStore(storageURL: makeTempURL())
        // Pass a preset-style config with isUserAdded == false
        let app = AppConfig.makePreset(name: "PresetApp")
        store.addApp(app)
        let stored = store.customApps.first { $0.bundleId == app.bundleId }
        #expect(stored?.isUserAdded == true)
    }

    @Test("addApp：category 强制设为 .custom")
    func addAppSetsCategory() {
        let store = UserConfigStore(storageURL: makeTempURL())
        let app = AppConfig.makePreset(name: "DevApp", category: .development)
        store.addApp(app)
        let stored = store.customApps.first { $0.bundleId == app.bundleId }
        #expect(stored?.category == .custom)
    }

    @Test("addApp：createdAt 近似当前时间（误差 < 5s）")
    func addAppCreatedAt() {
        let store = UserConfigStore(storageURL: makeTempURL())
        let before = Date()
        let app = AppConfig.makePreset(name: "TimedApp")
        store.addApp(app)
        let after = Date().addingTimeInterval(5)
        let stored = store.customApps.first { $0.bundleId == app.bundleId }!
        #expect(stored.createdAt >= before)
        #expect(stored.createdAt <= after)
    }

    // MARK: - updateApp

    @Test("updateApp：name 更新后体现在 customApps")
    func updateAppName() {
        let store = UserConfigStore(storageURL: makeTempURL())
        store.addApp(AppConfig.makeCustom(name: "OldName", bundleId: "com.test.update"))
        guard var stored = store.customApps.first(where: { $0.bundleId == "com.test.update" }) else {
            Issue.record("App not found after addApp")
            return
        }
        stored.name = "NewName"
        store.updateApp(stored)
        #expect(store.customApps.first(where: { $0.id == stored.id })?.name == "NewName")
    }

    @Test("updateApp：不存在的 id → customApps 不变，无崩溃")
    func updateNonExistent() {
        let store = UserConfigStore(storageURL: makeTempURL())
        store.addApp(AppConfig.makeCustom(name: "ExistingApp"))
        let countBefore = store.customApps.count
        // App with a fresh UUID won't exist in the store
        let ghost = AppConfig.makeCustom(name: "Ghost")
        store.updateApp(ghost)
        #expect(store.customApps.count == countBefore)
    }

    // MARK: - removeApps

    @Test("removeApps：正确 id 被移除")
    func removeAppsById() {
        let store = UserConfigStore(storageURL: makeTempURL())
        store.addApp(AppConfig.makeCustom(name: "RemoveMe", bundleId: "com.test.remove"))
        guard let stored = store.customApps.first(where: { $0.bundleId == "com.test.remove" }) else {
            Issue.record("App not found after addApp")
            return
        }
        store.removeApps([stored.id])
        #expect(!store.customApps.contains { $0.id == stored.id })
    }

    @Test("removeApps：传入空 Set → 无操作")
    func removeAppsEmptySet() {
        let store = UserConfigStore(storageURL: makeTempURL())
        store.addApp(AppConfig.makeCustom(name: "KeepMe"))
        let countBefore = store.customApps.count
        store.removeApps([])
        #expect(store.customApps.count == countBefore)
    }

    // MARK: - batchUpdate

    @Test("batchUpdate：全量替换 customApps")
    func batchUpdateReplaces() {
        let store = UserConfigStore(storageURL: makeTempURL())
        store.addApp(AppConfig.makeCustom(name: "OldApp"))
        let newApps = [
            AppConfig.makeCustom(name: "BatchApp1"),
            AppConfig.makeCustom(name: "BatchApp2"),
        ]
        store.batchUpdate(newApps)
        #expect(store.customApps.count == 2)
        #expect(store.customApps.contains { $0.name == "BatchApp1" })
        #expect(store.customApps.contains { $0.name == "BatchApp2" })
    }

    @Test("batchUpdate：每个 app 的 isUserAdded / category 被正规化")
    func batchUpdateNormalizes() {
        let store = UserConfigStore(storageURL: makeTempURL())
        // Pass preset-style apps; batchUpdate must enforce isUserAdded/category
        let apps = [
            AppConfig.makePreset(name: "ShouldBeCustom1"),
            AppConfig.makePreset(name: "ShouldBeCustom2"),
        ]
        store.batchUpdate(apps)
        #expect(store.customApps.allSatisfy { $0.isUserAdded && $0.category == .custom })
    }

    // MARK: - bundleIdExists

    @Test("bundleIdExists：已存在时返回 true")
    func bundleIdExistsTrue() {
        let store = UserConfigStore(storageURL: makeTempURL())
        store.addApp(AppConfig.makeCustom(name: "CheckApp", bundleId: "com.check.exists"))
        #expect(store.bundleIdExists("com.check.exists"))
    }

    @Test("bundleIdExists：不存在时返回 false")
    func bundleIdExistsFalse() {
        let store = UserConfigStore(storageURL: makeTempURL())
        #expect(!store.bundleIdExists("com.nonexistent.app"))
    }

    // MARK: - Event broadcasting
    //
    // addApp/removeApps/batchUpdate call broadcast(_:) synchronously, which yields
    // to all active continuations immediately. Since AsyncStream uses .unbounded
    // buffering, the event is already in the buffer when iterator.next() is awaited.

    @Test("addApp 广播 .appAdded 事件")
    func addAppBroadcastsEvent() async {
        let store = UserConfigStore(storageURL: makeTempURL())
        let stream = store.subscribe()
        store.addApp(AppConfig.makeCustom(name: "EventApp", bundleId: "com.event.add"))

        var iterator = stream.makeAsyncIterator()
        let event = await iterator.next()

        guard case .appAdded(let received) = event else {
            Issue.record("Expected .appAdded, got \(String(describing: event))")
            return
        }
        #expect(received.name == "EventApp")
        #expect(received.isUserAdded)
        #expect(received.category == .custom)
    }

    @Test("removeApps 广播 .appsRemoved 事件，包含目标 id")
    func removeAppsBroadcastsEvent() async {
        let store = UserConfigStore(storageURL: makeTempURL())
        store.addApp(AppConfig.makeCustom(name: "EventRemove", bundleId: "com.event.remove"))
        guard let stored = store.customApps.first(where: { $0.bundleId == "com.event.remove" }) else {
            Issue.record("App not found after addApp")
            return
        }

        let stream = store.subscribe()
        var iterator = stream.makeAsyncIterator()
        store.removeApps([stored.id])

        let event = await iterator.next()
        guard case .appsRemoved(let ids) = event else {
            Issue.record("Expected .appsRemoved, got \(String(describing: event))")
            return
        }
        #expect(ids.contains(stored.id))
    }

    @Test("batchUpdate 广播 .batchUpdated 事件，app 数量匹配")
    func batchUpdateBroadcastsEvent() async {
        let store = UserConfigStore(storageURL: makeTempURL())
        let newApps = [AppConfig.makeCustom(name: "BatchEvt1"), AppConfig.makeCustom(name: "BatchEvt2")]

        let stream = store.subscribe()
        var iterator = stream.makeAsyncIterator()
        store.batchUpdate(newApps)

        let event = await iterator.next()
        guard case .batchUpdated(let apps) = event else {
            Issue.record("Expected .batchUpdated, got \(String(describing: event))")
            return
        }
        #expect(apps.count == newApps.count)
    }
}
