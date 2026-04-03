//
//  AppLogger.swift
//  PocketPrefs
//
//  Unified logging facade with normalized subsystem/category routing.
//

import Foundation
import os.log

final class AppLogger: Sendable {
    static let shared = AppLogger()
    private static let subsystem = "com.me2.PocketPrefs"

    enum Category: String {
        case app = "App"
        case coordinator = "MainCoordinator"
        case backup = "BackupService"
        case restore = "RestoreService"
        case backupManagement = "BackupManagementService"
        case backupManagementVM = "BackupManagementViewModel"
        case fileOperation = "FileOperation"
        case userConfig = "UserConfigStore"
        case deletedPreset = "DeletedPresetStore"
        case importExport = "ImportExport"
        case icon = "IconService"
        case preferences = "PreferencesManager"
        case appInfoReader = "AppInfoReader"
        case customAppManager = "CustomAppManager"
        case coordinatorEvents = "CoordinatorEventPublisher"
        case operationEvents = "OperationEventPublisher"
        case settingsEvents = "SettingsEventPublisher"
    }

    private init() {}

    private func make(_ category: Category) -> Logger {
        Logger(subsystem: Self.subsystem, category: category.rawValue)
    }

    func debug(_ message: String, category: Category) {
        make(category).debug("\(message)")
    }

    func info(_ message: String, category: Category) {
        make(category).info("\(message)")
    }

    func warning(_ message: String, category: Category) {
        make(category).warning("\(message)")
    }

    func error(_ message: String, category: Category) {
        make(category).error("\(message)")
    }
}
