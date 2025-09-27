//
//  FileOperationService.swift
//  PocketPrefs
//
//  File operation utilities with async support
//

import AppKit
import Foundation
import os.log

actor FileOperationService {
    static let shared = FileOperationService()
    private let logger = Logger(subsystem: "com.pocketprefs", category: "FileOperation")
    
    private init() {}
    
    func checkIfAppInstalled(bundleId: String) async -> Bool {
        let fileManager = FileManager.default
        
        switch bundleId {
        case "oh-my-zsh":
            return fileManager.fileExists(atPath: NSHomeDirectory() + "/.oh-my-zsh")
        case "git":
            return fileManager.fileExists(atPath: NSHomeDirectory() + "/.gitconfig")
        case "ssh":
            return fileManager.fileExists(atPath: NSHomeDirectory() + "/.ssh")
        case "homebrew":
            return fileManager.fileExists(atPath: "/usr/local/bin/brew") ||
                fileManager.fileExists(atPath: "/opt/homebrew/bin/brew")
        default:
            return await MainActor.run {
                NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
            }
        }
    }
    
    func copyFile(from source: String, to destination: String) async throws {
        let fileManager = FileManager.default
        let expandedSource = NSString(string: source).expandingTildeInPath
        let expandedDest = NSString(string: destination).expandingTildeInPath
        
        // Ensure destination directory exists
        let destDir = URL(fileURLWithPath: expandedDest).deletingLastPathComponent().path
        if !fileManager.fileExists(atPath: destDir) {
            try fileManager.createDirectory(
                atPath: destDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        
        // Remove existing file if exists
        if fileManager.fileExists(atPath: expandedDest) {
            try fileManager.removeItem(atPath: expandedDest)
        }
        
        // Copy file
        try fileManager.copyItem(atPath: expandedSource, toPath: expandedDest)
        logger.debug("Copied file from \(source) to \(destination)")
    }
    
    func backupExistingFile(_ path: String) async throws {
        let fileManager = FileManager.default
        let expandedPath = NSString(string: path).expandingTildeInPath
        
        if fileManager.fileExists(atPath: expandedPath) {
            let backupPath = expandedPath + ".pocketprefs_backup"
            
            if fileManager.fileExists(atPath: backupPath) {
                try fileManager.removeItem(atPath: backupPath)
            }
            
            try fileManager.moveItem(atPath: expandedPath, toPath: backupPath)
            logger.info("Backed up existing file: \(path)")
        }
    }
    
    func createDirectory(at path: String) async throws {
        let fileManager = FileManager.default
        let expandedPath = NSString(string: path).expandingTildeInPath
        try fileManager.createDirectory(
            atPath: expandedPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    func fileExists(at path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
}
