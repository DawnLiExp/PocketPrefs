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
                attributes: nil,
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
            attributes: nil,
        )
    }
    
    func fileExists(at path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
    
    // MARK: - File Size Calculation
    
    func calculateFileSize(at path: String) async -> String {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        
        do {
            let resourceValues = try url.resourceValues(
                forKeys: [.totalFileSizeKey, .fileSizeKey, .isDirectoryKey],
            )
            
            let size: Int64 = if resourceValues.isDirectory == true {
                await calculateDirectorySize(at: url)
            } else {
                Int64(resourceValues.totalFileSize ?? resourceValues.fileSize ?? 0)
            }
            
            return formatFileSize(size)
        } catch {
            return "Not Found"
        }
    }
    
    private func calculateDirectorySize(at url: URL) async -> Int64 {
        // Collect URLs synchronously to avoid async enumerator issues
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileSizeKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
        ) else {
            return 0
        }
        
        let fileURLs = enumerator.compactMap { $0 as? URL }
        
        var totalSize: Int64 = 0
        for fileURL in fileURLs {
            do {
                let resourceValues = try fileURL.resourceValues(
                    forKeys: [.totalFileSizeKey, .fileSizeKey],
                )
                let fileSize = Int64(resourceValues.totalFileSize ?? resourceValues.fileSize ?? 0)
                totalSize += fileSize
            } catch {
                continue
            }
        }
        
        return totalSize
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: size)
    }
}
