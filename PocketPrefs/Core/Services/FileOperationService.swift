//
//  FileOperationService.swift
//  PocketPrefs
//
//  File operation utilities with async support
//

import AppKit
import Darwin
import Foundation
import os.log

actor FileOperationService {
    static let shared = FileOperationService()
    
    private let logger = Logger(subsystem: "com.me2.PocketPrefs", category: "FileOperation")
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
    
    /// Carry a complete archived app, including metadata unknown to this release.
    func copyArchivedApp(_ app: BackupAppInfo, to root: URL) throws {
        let staging = root.appendingPathComponent(".copy-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: staging) }
        try fileManager.copyItem(at: URL(fileURLWithPath: app.path), to: staging)
        let data = try Data(contentsOf: staging.appendingPathComponent(BackupManifest.filename))
        let manifest = try JSONDecoder().decode(BackupManifest.self, from: data)
        guard manifest.app.bundleId == app.bundleId else { throw AppError.invalidBackupFormat(path: app.path) }
        let plan = BackupManifest.restorePlan(paths: manifest.app.configPaths, mapping: manifest.entries)
        guard !plan.entries.isEmpty, plan.issues.reasons.isEmpty else { throw plan.issues }
        for entry in plan.entries {
            do {
                _ = try fileManager.attributesOfItem(atPath: staging.appendingPathComponent(entry.storedName).path)
            } catch {
                throw AppError.fileOperationFailed(path: entry.originalPath, underlying: error)
            }
        }
        try fileManager.moveItem(at: staging, to: BackupManifest.directory(in: root, bundleID: app.bundleId))
    }

    /// Copy completely on the destination volume before changing the live item or its previous version.
    func restoreItem(from source: URL, to originalPath: String, keepPrevious: Bool) throws {
        let destination = URL(fileURLWithPath: expandPath(originalPath))
        _ = try fileManager.attributesOfItem(atPath: source.path)
        let parent = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        let workspace = parent.appendingPathComponent(".pocketprefs-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: workspace, withIntermediateDirectories: false)

        let candidate = workspace.appendingPathComponent("new")
        do {
            try fileManager.copyItem(at: source, to: candidate)
            if let previous = try install(candidate, at: destination, in: workspace), keepPrevious {
                let backup = URL(fileURLWithPath: destination.path + ".pocketprefs_backup")
                do {
                    _ = try install(previous, at: backup, in: workspace)
                } catch {
                    // Rotation failed. Put the old live item back before reporting the failure.
                    do { _ = try install(previous, at: destination, in: workspace) }
                    catch { throw RestoreRollbackError(savedItem: previous, underlying: error) }
                    throw error
                }
            }
        } catch let error as RestoreRollbackError {
            // Its saved item can be the only remaining original.
            throw error
        } catch {
            try? fileManager.removeItem(at: workspace)
            throw error
        }
        try? fileManager.removeItem(at: workspace)
    }

    /// Returns the displaced item inside the workspace, or nil when installing at a new path.
    private func install(_ candidate: URL, at target: URL, in workspace: URL) throws -> URL? {
        do {
            _ = try fileManager.attributesOfItem(atPath: target.path)
        } catch CocoaError.fileReadNoSuchFile {
            try fileManager.moveItem(at: candidate, to: target)
            return nil
        }
        // Swap directory entries, including symbolic links and non-empty directories.
        if renamex_np(candidate.path, target.path, UInt32(RENAME_SWAP)) == 0 { return candidate }
        let code = errno
        guard code == ENOTSUP || code == EINVAL || code == ENOSYS else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(code), userInfo: [NSFilePathErrorKey: target.path])
        }

        // Volumes without exchange support use same-volume moves and retain the original for rollback.
        let previous = workspace.appendingPathComponent(UUID().uuidString)
        try fileManager.moveItem(at: target, to: previous)
        do {
            try fileManager.moveItem(at: candidate, to: target)
        } catch {
            do { try fileManager.moveItem(at: previous, to: target) }
            catch { throw RestoreRollbackError(savedItem: previous, underlying: error) }
            throw error
        }
        return previous
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

private struct RestoreRollbackError: LocalizedError {
    let savedItem: URL
    let underlying: Error

    var errorDescription: String? {
        String(localized: "Restore_Rollback_Error", defaultValue: "Could not roll back the replacement. The displaced item is at \(savedItem.path). \(underlying.localizedDescription)")
    }
}
