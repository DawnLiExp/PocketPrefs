//
//  PreferencesManager.swift
//  PocketPrefs
//
//  Manages application preferences including backup directory configuration
//

import Foundation
import os.log
import SwiftUI

@MainActor
final class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()
    
    private let logger = Logger(subsystem: "com.pocketprefs", category: "PreferencesManager")
    
    private static let defaultBackupPath = NSHomeDirectory() + "/Documents/PocketPrefsBackups"
    
    @AppStorage("backupDirectory") private var storedBackupDirectory: String = ""
    @Published var backupDirectory: String = ""
    @Published var directoryStatus: DirectoryStatus = .unknown
    
    enum DirectoryStatus: Equatable {
        case unknown
        case valid
        case invalid(reason: String)
        case creating
    }
    
    private init() {
        // Initialize backupDirectory first
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
    
    // MARK: - Public Methods
    
    func setBackupDirectory(_ path: String) async {
        let expandedPath = NSString(string: path).expandingTildeInPath
        backupDirectory = expandedPath
        storedBackupDirectory = expandedPath
        
        await validateAndCreateDirectory()
        
        logger.info("Backup directory updated: \(expandedPath)")
    }
    
    func getBackupDirectory() -> String {
        backupDirectory
    }
    
    func validateAndCreateDirectory() async {
        directoryStatus = .creating
        
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        if fileManager.fileExists(atPath: backupDirectory, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                directoryStatus = .valid
                logger.info("Backup directory validated: \(self.backupDirectory)")
            } else {
                directoryStatus = .invalid(reason: NSLocalizedString("Preferences_Error_Not_Directory", comment: ""))
                logger.error("Path exists but is not a directory: \(self.backupDirectory)")
            }
        } else {
            do {
                try fileManager.createDirectory(
                    atPath: backupDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil,
                )
                directoryStatus = .valid
                logger.info("Backup directory created: \(self.backupDirectory)")
            } catch {
                directoryStatus = .invalid(reason: error.localizedDescription)
                logger.error("Failed to create backup directory: \(error)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
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
