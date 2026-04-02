//
//  AppConfig+TestData.swift
//  PocketPrefsTests
//

import Foundation
@testable import PocketPrefs

extension AppConfig {
    /// Creates a preset-style AppConfig (isUserAdded == false, createdAt == epoch).
    static func makePreset(
        name: String,
        bundleId: String? = nil,
        category: AppCategory = .utility
    ) -> AppConfig {
        AppConfig(
            name: name,
            bundleId: bundleId ?? "preset.\(name.lowercased())",
            configPaths: ["~/.config/\(name.lowercased())"],
            category: category,
            isUserAdded: false,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    /// Creates a user-added custom AppConfig (isUserAdded == true, category == .custom).
    static func makeCustom(
        name: String,
        bundleId: String? = nil,
        createdAt: Date = .now
    ) -> AppConfig {
        AppConfig(
            name: name,
            bundleId: bundleId ?? "com.test.\(name.lowercased())",
            configPaths: ["~/.\(name.lowercased())rc"],
            category: .custom,
            isUserAdded: true,
            createdAt: createdAt
        )
    }
}

extension BackupAppInfo {
    /// Creates a minimal BackupAppInfo suitable for sort / selection tests.
    static func make(name: String, bundleId: String? = nil) -> BackupAppInfo {
        BackupAppInfo(
            name: name,
            path: "/tmp/\(name)",
            bundleId: bundleId ?? "com.test.\(name.lowercased())",
            configPaths: [],
            isCurrentlyInstalled: true,
            isSelected: false,
            category: .custom
        )
    }
}
