//
//  AppError.swift
//  PocketPrefs
//
//  Application error definitions and handling
//

import Foundation

enum AppError: LocalizedError {
    case fileOperationFailed(path: String, underlying: Error)
    case backupDirectoryCreationFailed(Error)
    case configDecodingFailed(app: String, Error)
    case configEncodingFailed(app: String, Error)
    case invalidBackupFormat(path: String)
    case noAppsSelected
    case backupNotFound(path: String)
    case restoreFailed(app: String, reason: String)
    case iconLoadFailed(bundleId: String)
    case applicationRestartFailed(Error)
    case preferencesSaveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .fileOperationFailed(let path, let error):
            return "File operation failed at \(path): \(error.localizedDescription)"
        case .backupDirectoryCreationFailed(let error):
            return "Failed to create backup directory: \(error.localizedDescription)"
        case .configDecodingFailed(let app, let error):
            return "Failed to decode config for \(app): \(error.localizedDescription)"
        case .configEncodingFailed(let app, let error):
            return "Failed to encode config for \(app): \(error.localizedDescription)"
        case .invalidBackupFormat(let path):
            return "Invalid backup format at: \(path)"
        case .noAppsSelected:
            return "No applications selected for operation"
        case .backupNotFound(let path):
            return "Backup not found at: \(path)"
        case .restoreFailed(let app, let reason):
            return "Failed to restore \(app): \(reason)"
        case .iconLoadFailed(let bundleId):
            return "Failed to load icon for: \(bundleId)"
        case .applicationRestartFailed(let error):
            return "Failed to restart application: \(error.localizedDescription)"
        case .preferencesSaveFailed(let error):
            return "Failed to save preferences: \(error.localizedDescription)"
        }
    }
}
