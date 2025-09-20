//
//  BackupModels.swift
//  PocketPrefs
//
//  Backup-related data models
//

import Foundation

// MARK: - Backup Information

struct BackupInfo: Identifiable, Hashable, Sendable {
    let id = UUID()
    let path: String
    let name: String
    let date: Date
    var apps: [BackupAppInfo] = []

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: BackupInfo, rhs: BackupInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Backup App Information

struct BackupAppInfo: Identifiable, Hashable, Sendable {
    let id = UUID()
    let name: String
    let path: String
    let bundleId: String
    let configPaths: [String]
    var isCurrentlyInstalled: Bool
    var isSelected: Bool
    let category: AppCategory // Add category for icon retrieval

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: BackupAppInfo, rhs: BackupAppInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Backup Operation Result

struct BackupResult: Sendable {
    let successCount: Int
    let failedApps: [(name: String, error: Error)]
    let totalProcessed: Int

    var isCompleteSuccess: Bool {
        failedApps.isEmpty && successCount > 0
    }

    var statusMessage: String {
        if isCompleteSuccess {
            return String(format: NSLocalizedString("Backup_Success_Message", comment: ""), successCount)
        } else if failedApps.isEmpty && successCount == 0 {
            return NSLocalizedString("Backup_No_Apps_Processed", comment: "")
        } else {
            let failedNames = failedApps.map { $0.name }.joined(separator: ", ")
            return String(format: NSLocalizedString("Backup_Partial_Success_Message", comment: ""),
                          successCount, failedNames)
        }
    }
}

// MARK: - Restore Operation Result

struct RestoreResult: Sendable {
    let successCount: Int
    let failedApps: [(name: String, error: Error)]
    let totalProcessed: Int

    var isCompleteSuccess: Bool {
        failedApps.isEmpty && successCount > 0
    }

    var statusMessage: String {
        if isCompleteSuccess {
            return String(format: NSLocalizedString("Restore_Success_Message", comment: ""), successCount)
        } else if failedApps.isEmpty && successCount == 0 {
            return NSLocalizedString("Restore_No_Apps_Processed", comment: "")
        } else {
            let failedNames = failedApps.map { $0.name }.joined(separator: ", ")
            return String(format: NSLocalizedString("Restore_Partial_Success_Message", comment: ""),
                          successCount, failedNames)
        }
    }
}
