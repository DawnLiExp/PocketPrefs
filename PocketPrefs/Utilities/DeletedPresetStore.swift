//
//  DeletedPresetStore.swift
//  PocketPrefs
//
//  Persists the set of preset bundle IDs the user has deleted.
//  Invariant: only preset bundleIds are stored here; custom apps use UserConfigStore.
//

import Foundation
import os.log

@MainActor
final class DeletedPresetStore {
    static let shared = DeletedPresetStore()

    private let logger = Logger(subsystem: "com.pocketprefs", category: "DeletedPresetStore")
    private let defaultsKey = "deletedPresetBundleIds"
    private let defaults: UserDefaults

    private(set) var deletedBundleIds: Set<String>

    private init() {
        self.defaults = .standard
        let stored = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        deletedBundleIds = Set(stored)
        logger.info("Loaded \(stored.count) deleted preset(s)")
    }

    // IMPORTANT: For testing only. Injects a separate UserDefaults suite so tests
    // never touch UserDefaults.standard and can be cleaned up after each run.
    init(defaults: UserDefaults) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: defaultsKey) ?? []
        deletedBundleIds = Set(stored)
    }

    func markDeleted(_ bundleId: String) {
        deletedBundleIds.insert(bundleId)
        persist()
        logger.info("Preset marked deleted: \(bundleId)")
    }

    private func persist() {
        defaults.set(Array(deletedBundleIds), forKey: defaultsKey)
    }
}
