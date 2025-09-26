//
//  ImportExportManager.swift
//  PocketPrefs
//
//  Import and export functionality for custom applications
//

import AppKit
import Foundation
import os.log
import UniformTypeIdentifiers

@MainActor
class ImportExportManager: ObservableObject {
    private let logger = Logger(subsystem: "com.pocketprefs", category: "ImportExport")
    private let userStore = UserConfigStore.shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    }
    
    // MARK: - Export
    
    func exportCustomApps() async {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "PocketPrefs_CustomApps_\(dateString()).json"
        panel.title = NSLocalizedString("Export_Title", comment: "")
        panel.message = NSLocalizedString("Export_Message", comment: "")
        
        let response = await panel.beginSheetModal(for: NSApp.keyWindow!)
        guard response == .OK, let url = panel.url else {
            logger.info("Export cancelled by user")
            return
        }
        
        await performExport(to: url)
    }
    
    private func performExport(to url: URL) async {
        do {
            let exportData = ExportData(
                version: 1,
                exportDate: Date(),
                customApps: userStore.customApps
            )
            
            let data = try encoder.encode(exportData)
            try data.write(to: url)
            
            logger.info("Successfully exported \(self.userStore.customApps.count) custom apps")
            await showSuccessAlert(
                message: String(format: NSLocalizedString("Export_Success", comment: ""),
                                userStore.customApps.count)
            )
        } catch {
            logger.error("Export failed: \(error)")
            await showErrorAlert(
                message: NSLocalizedString("Export_Failed", comment: ""),
                informativeText: error.localizedDescription
            )
        }
    }
    
    // MARK: - Import
    
    func importCustomApps() async {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.title = NSLocalizedString("Import_Title", comment: "")
        panel.message = NSLocalizedString("Import_Message", comment: "")
        
        let response = await panel.beginSheetModal(for: NSApp.keyWindow!)
        guard response == .OK, let url = panel.url else {
            logger.info("Import cancelled by user")
            return
        }
        
        await performImport(from: url)
    }
    
    private func performImport(from url: URL) async {
        do {
            let data = try Data(contentsOf: url)
            let exportData = try decoder.decode(ExportData.self, from: data)
            
            // Validate version compatibility
            guard exportData.version <= 1 else {
                throw ImportError.incompatibleVersion
            }
            
            // Show preview and confirmation
            let shouldProceed = await showImportConfirmation(
                newApps: exportData.customApps,
                existingApps: userStore.customApps
            )
            
            guard shouldProceed else {
                logger.info("Import cancelled after preview")
                return
            }
            
            // Perform merge
            let mergeResult = await mergeImportedApps(exportData.customApps)
            
            // Show result
            await showImportResult(mergeResult)
            
        } catch {
            logger.error("Import failed: \(error)")
            let errorMessage = error is ImportError ? error.localizedDescription :
                NSLocalizedString("Import_Failed", comment: "")
            await showErrorAlert(
                message: errorMessage,
                informativeText: error.localizedDescription
            )
        }
    }
    
    private func mergeImportedApps(_ importedApps: [AppConfig]) async -> MergeResult {
        var added = 0
        var updated = 0
        var skipped = 0
        
        for importedApp in importedApps {
            if let existingIndex = userStore.customApps.firstIndex(where: { $0.bundleId == importedApp.bundleId }) {
                // Update existing app if paths differ
                let existingApp = userStore.customApps[existingIndex]
                if Set(existingApp.configPaths) != Set(importedApp.configPaths) {
                    var mergedApp = existingApp
                    // Merge paths (union)
                    let mergedPaths = Set(existingApp.configPaths).union(Set(importedApp.configPaths))
                    mergedApp.configPaths = Array(mergedPaths).sorted()
                    userStore.updateApp(mergedApp)
                    updated += 1
                } else {
                    skipped += 1
                }
            } else {
                // Add new app
                userStore.addApp(importedApp)
                added += 1
            }
        }
        
        return MergeResult(added: added, updated: updated, skipped: skipped)
    }
    
    // MARK: - UI Helpers
    
    private func showImportConfirmation(newApps: [AppConfig], existingApps: [AppConfig]) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = NSLocalizedString("Import_Confirmation_Title", comment: "")
                
                let existingBundleIds = Set(existingApps.map { $0.bundleId })
                let newCount = newApps.filter { !existingBundleIds.contains($0.bundleId) }.count
                let updateCount = newApps.filter { existingBundleIds.contains($0.bundleId) }.count
                
                alert.informativeText = String(
                    format: NSLocalizedString("Import_Confirmation_Message", comment: ""),
                    newApps.count,
                    newCount,
                    updateCount
                )
                
                alert.addButton(withTitle: NSLocalizedString("Import_Proceed", comment: ""))
                alert.addButton(withTitle: NSLocalizedString("Common_Cancel", comment: ""))
                
                continuation.resume(returning: alert.runModal() == .alertFirstButtonReturn)
            }
        }
    }
    
    private func showImportResult(_ result: MergeResult) async {
        await showSuccessAlert(
            message: String(
                format: NSLocalizedString("Import_Result", comment: ""),
                result.added,
                result.updated,
                result.skipped
            )
        )
    }
    
    private func showSuccessAlert(message: String) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = NSLocalizedString("Success", comment: "")
                alert.informativeText = message
                alert.alertStyle = .informational
                alert.runModal()
                continuation.resume()
            }
        }
    }
    
    private func showErrorAlert(message: String, informativeText: String) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = message
                alert.informativeText = informativeText
                alert.alertStyle = .warning
                alert.runModal()
                continuation.resume()
            }
        }
    }
    
    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// MARK: - Data Models

struct ExportData: Codable {
    let version: Int
    let exportDate: Date
    let customApps: [AppConfig]
}

struct MergeResult {
    let added: Int
    let updated: Int
    let skipped: Int
}

enum ImportError: LocalizedError {
    case incompatibleVersion
    case invalidFormat
    
    var errorDescription: String? {
        switch self {
        case .incompatibleVersion:
            return NSLocalizedString("Import_Error_Version", comment: "")
        case .invalidFormat:
            return NSLocalizedString("Import_Error_Format", comment: "")
        }
    }
}
