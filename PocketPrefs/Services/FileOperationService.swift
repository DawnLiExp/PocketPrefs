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
    private let fileManager = FileManager.default
    
    private init() {}
    
    // MARK: - App Detection
    
    func checkIfAppInstalled(bundleId: String) async -> Bool {
        switch bundleId {
        case "oh-my-zsh":
            return fileExists(atPath: NSHomeDirectory() + "/.oh-my-zsh")
        case "git":
            return fileExists(atPath: NSHomeDirectory() + "/.gitconfig")
        case "ssh":
            return fileExists(atPath: NSHomeDirectory() + "/.ssh")
        case "homebrew":
            return fileExists(atPath: "/usr/local/bin/brew") ||
                fileExists(atPath: "/opt/homebrew/bin/brew")
        default:
            return await checkAppBundle(bundleId: bundleId)
        }
    }
    
    private func checkAppBundle(bundleId: String) async -> Bool {
        await MainActor.run {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
        }
    }
    
    // MARK: - File Operations
    
    func copyFile(from source: String, to destination: String) async throws {
        let expandedSource = expandPath(source)
        let expandedDest = expandPath(destination)
        
        try await ensureDestinationDirectory(for: expandedDest)
        try removeIfExists(at: expandedDest)
        
        do {
            try fileManager.copyItem(atPath: expandedSource, toPath: expandedDest)
            logger.debug("Copied: \(source) → \(destination)")
        } catch {
            logger.error("Copy failed: \(source) → \(destination) - \(error.localizedDescription)")
            throw error
        }
    }
    
    func backupExistingFile(_ path: String) async throws {
        let expandedPath = expandPath(path)
        
        guard fileExists(atPath: expandedPath) else { return }
        
        let backupPath = expandedPath + ".pocketprefs_backup"
        try removeIfExists(at: backupPath)
        
        do {
            try fileManager.moveItem(atPath: expandedPath, toPath: backupPath)
            logger.info("Backed up: \(path)")
        } catch {
            logger.error("Backup failed: \(path) - \(error.localizedDescription)")
            throw error
        }
    }
    
    func createDirectory(at path: String) async throws {
        let expandedPath = expandPath(path)
        
        do {
            try fileManager.createDirectory(
                atPath: expandedPath,
                withIntermediateDirectories: true,
                attributes: nil,
            )
            logger.debug("Created directory: \(path)")
        } catch {
            logger.error("Directory creation failed: \(path) - \(error.localizedDescription)")
            throw error
        }
    }
    
    func fileExists(at path: String) async -> Bool {
        fileExists(atPath: expandPath(path))
    }
    
    // MARK: - File Size Calculation
    
    func calculateFileSize(at path: String) async -> String {
        let url = URL(fileURLWithPath: expandPath(path))
        
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
            logger.debug("Size calculation failed for: \(path)")
            return "Not Found"
        }
    }
    
    // MARK: - Private Helpers
    
    private func expandPath(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }
    
    private func fileExists(atPath path: String) -> Bool {
        fileManager.fileExists(atPath: path)
    }
    
    private func removeIfExists(at path: String) throws {
        if fileExists(atPath: path) {
            try fileManager.removeItem(atPath: path)
        }
    }
    
    private func ensureDestinationDirectory(for filePath: String) async throws {
        let destDir = URL(fileURLWithPath: filePath).deletingLastPathComponent().path
        
        if !fileExists(atPath: destDir) {
            try fileManager.createDirectory(
                atPath: destDir,
                withIntermediateDirectories: true,
                attributes: nil,
            )
        }
    }
    
    private func calculateDirectorySize(at url: URL) async -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileSizeKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
        ) else {
            return 0
        }
        
        let fileURLs = enumerator.compactMap { $0 as? URL }
        
        return fileURLs.reduce(0) { total, fileURL in
            guard let resourceValues = try? fileURL.resourceValues(
                forKeys: [.totalFileSizeKey, .fileSizeKey],
            ) else {
                return total
            }
            
            let fileSize = Int64(resourceValues.totalFileSize ?? resourceValues.fileSize ?? 0)
            return total + fileSize
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: size)
    }
}
