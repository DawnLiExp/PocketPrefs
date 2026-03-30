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

    private(set) var deletedBundleIds: Set<String>

    private init() {
        let stored = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        deletedBundleIds = Set(stored)
        logger.info("Loaded \(stored.count) deleted preset(s)")
    }

    func markDeleted(_ bundleId: String) {
        deletedBundleIds.insert(bundleId)
        persist()
        logger.info("Preset marked deleted: \(bundleId)")
    }

    private func persist() {
        UserDefaults.standard.set(Array(deletedBundleIds), forKey: defaultsKey)
    }
}
