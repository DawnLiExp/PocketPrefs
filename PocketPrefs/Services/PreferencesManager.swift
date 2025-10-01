//
//  PreferencesManager.swift
//  PocketPrefs
//
//  Manages application preferences with AsyncStream events
//

import Foundation
import os.log
import SwiftUI

// MARK: - Preferences Events

enum PreferencesEvent: Sendable {
    case directoryChanged(path: String)
    case statusUpdated(PreferencesManager.DirectoryStatus)
}

// MARK: - Preferences Manager

@MainActor
final class PreferencesManager: ObservableObject {
    enum DirectoryStatus: Equatable, Sendable {
        case unknown
        case valid
        case invalid(reason: String)
        case creating
    }

    static let shared = PreferencesManager()
    
    private let logger = Logger(subsystem: "com.pocketprefs", category: "PreferencesManager")
    private static let defaultBackupPath = NSHomeDirectory() + "/Documents/PocketPrefsBackups"
    
    @AppStorage("backupDirectory") private var storedBackupDirectory: String = ""
    @Published var backupDirectory: String = ""
    @Published var directoryStatus: DirectoryStatus = .unknown
    
    private var continuation: AsyncStream<PreferencesEvent>.Continuation?
    let events: AsyncStream<PreferencesEvent>
    
    private init() {
        let (stream, continuation) = AsyncStream<PreferencesEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(1),
        )
        self.events = stream
        self.continuation = continuation
        
        if storedBackupDirectory.isEmpty {
            storedBackupDirectory = Self.defaultBackupPath
            backupDirectory = Self.defaultBackupPath
        } else {
            backupDirectory = storedBackupDirectory
        }
        
        Task {
            await validateAndCreateDirectory()
        }
    }
    
    deinit {
        continuation?.finish()
    }
    
    // MARK: - Public API
    
    func setBackupDirectory(_ path: String) async {
        let expandedPath = NSString(string: path).expandingTildeInPath
        backupDirectory = expandedPath
        storedBackupDirectory = expandedPath
        
        await validateAndCreateDirectory()
        
        if case .valid = directoryStatus {
            continuation?.yield(.directoryChanged(path: expandedPath))
            logger.info("Backup directory changed: \(expandedPath)")
        }
    }
    
    func getBackupDirectory() -> String {
        backupDirectory
    }
    
    func validateAndCreateDirectory() async {
        directoryStatus = .creating
        continuation?.yield(.statusUpdated(.creating))
        
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        if fileManager.fileExists(atPath: backupDirectory, isDirectory: &isDirectory) {
            let newStatus: DirectoryStatus = isDirectory.boolValue
                ? .valid
                : .invalid(reason: NSLocalizedString("Preferences_Error_Not_Directory", comment: ""))
            
            directoryStatus = newStatus
            continuation?.yield(.statusUpdated(newStatus))
            
            if case .valid = newStatus {
                logger.info("Directory validated: \(self.backupDirectory)")
            } else {
                logger.error("Path exists but not directory: \(self.backupDirectory)")
            }
        } else {
            do {
                try fileManager.createDirectory(
                    atPath: backupDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil,
                )
                directoryStatus = .valid
                continuation?.yield(.statusUpdated(.valid))
                logger.info("Directory created: \(self.backupDirectory)")
            } catch {
                let newStatus = DirectoryStatus.invalid(reason: error.localizedDescription)
                directoryStatus = newStatus
                continuation?.yield(.statusUpdated(newStatus))
                logger.error("Failed to create directory: \(error)")
            }
        }
    }
    
    // MARK: - Helpers
    
    func isDefaultPath() -> Bool {
        backupDirectory == Self.defaultBackupPath
    }
    
    func getDisplayPath() -> String {
        let homePath = NSHomeDirectory()
        if backupDirectory.hasPrefix(homePath) {
            return "~" + backupDirectory.dropFirst(homePath.count)
        }
        return backupDirectory
    }
}
