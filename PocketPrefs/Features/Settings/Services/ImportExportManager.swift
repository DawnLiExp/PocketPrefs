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
final class ImportExportManager {
    private let logger = Logger(subsystem: "com.pocketprefs", category: "ImportExport")
    private let userStore = UserConfigStore.shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    }
    
    // MARK: - Export
    
    func exportCustomApps(selectedIds: Set<UUID>? = nil) async {
        // Determine apps to export
        let appsToExport: [AppConfig]
        let exportTypeMessage: String
        
        if let selectedIds, !selectedIds.isEmpty {
            appsToExport = userStore.customApps.filter { selectedIds.contains($0.id) }
            exportTypeMessage = String(localized: "Export_Selected_Message", defaultValue: "Export \(appsToExport.count) selected apps configuration")
        } else {
            appsToExport = userStore.customApps
            exportTypeMessage = String(localized: "Export_All_Message")
        }
        
        guard !appsToExport.isEmpty else {
            logger.warning("No apps to export")
            return
        }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "PocketPrefs_CustomApps_\(dateString()).json"
        panel.title = String(localized: "Export_Title")
        panel.message = exportTypeMessage
        
        let response = await panel.beginSheetModal(for: NSApp.keyWindow!)
        guard response == .OK, let url = panel.url else {
            logger.info("Export cancelled by user")
            return
        }
        
        await performExport(apps: appsToExport, to: url)
    }
    
    private func performExport(apps: [AppConfig], to url: URL) async {
        do {
            let exportData = ExportData(
                version: 1,
                exportDate: Date(),
                customApps: apps,
            )
            
            let data = try encoder.encode(exportData)
            try data.write(to: url)
            
            logger.info("Successfully exported \(apps.count) custom apps")
            await showSuccessAlert(
                message: String(localized: "Export_Success", defaultValue: "Successfully exported \(apps.count) app configuration(s)"),
            )
        } catch {
            logger.error("Export failed: \(error)")
            await showErrorAlert(
                message: String(localized: "Export_Failed"),
                informativeText: error.localizedDescription,
            )
        }
    }
    
    // MARK: - Import
    
    func importCustomApps() async {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.title = String(localized: "Import_Title")
        panel.message = String(localized: "Import_Message")
        
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
                existingApps: userStore.customApps,
            )
            
            guard shouldProceed else {
                logger.info("Import cancelled after preview")
                return
            }
            
            // Perform merge
            let mergeResult = await mergeImportedApps(exportData.customApps)
            
            // Small delay to ensure UI updates
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            // Show result
            await showImportResult(mergeResult)
            
        } catch {
            logger.error("Import failed: \(error)")
            let errorMessage = error is ImportError ? error.localizedDescription :
                String(localized: "Import_Failed")
            await showErrorAlert(
                message: errorMessage,
                informativeText: error.localizedDescription,
            )
        }
    }
    
    private func mergeImportedApps(_ importedApps: [AppConfig]) async -> MergeResult {
        var added = 0
        var updated = 0
        var skipped = 0
        
        // Build final app list in-place
        var finalApps: [AppConfig] = []
        let existingByBundleId = Dictionary(
            userStore.customApps.map { ($0.bundleId, $0) },
            uniquingKeysWith: { first, _ in first },
        )
        
        // Process imports
        for importedApp in importedApps {
            if let existingApp = existingByBundleId[importedApp.bundleId] {
                // Check if update needed
                let pathsChanged = Set(existingApp.configPaths) != Set(importedApp.configPaths)
                let nameChanged = existingApp.name != importedApp.name
                
                if pathsChanged || nameChanged {
                    // Update existing app
                    var replacementApp = importedApp
                    replacementApp.id = existingApp.id
                    replacementApp.isUserAdded = true
                    replacementApp.category = .custom
                    finalApps.append(replacementApp)
                    updated += 1
                    
                    logger.info("Updated app: \(replacementApp.name) with \(replacementApp.configPaths.count) paths")
                } else {
                    // Keep existing unchanged
                    finalApps.append(existingApp)
                    skipped += 1
                    logger.info("Skipped unchanged app: \(existingApp.name)")
                }
            } else {
                // Add new app
                var newApp = importedApp
                newApp.id = UUID()
                newApp.isUserAdded = true
                newApp.category = .custom
                finalApps.append(newApp)
                added += 1
                
                logger.info("Added new app: \(newApp.name) with \(newApp.configPaths.count) paths")
            }
        }
        
        // Add existing apps not in import
        for existingApp in userStore.customApps {
            if !importedApps.contains(where: { $0.bundleId == existingApp.bundleId }) {
                finalApps.append(existingApp)
            }
        }
        
        // Single batch update
        userStore.batchUpdate(finalApps)
        
        return MergeResult(added: added, updated: updated, skipped: skipped)
    }
    
    // MARK: - UI Helpers
    
    private func showImportConfirmation(newApps: [AppConfig], existingApps: [AppConfig]) async -> Bool {
        await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText = String(localized: "Import_Confirmation_Title")
            
            let existingBundleIds = Set(existingApps.map(\.bundleId))
            let newCount = newApps.count(where: { !existingBundleIds.contains($0.bundleId) })
            let updateCount = newApps.count(where: { existingBundleIds.contains($0.bundleId) })
            
            var detailMessage = String(localized: "Import_Confirmation_Message", defaultValue: "Found \(newApps.count) apps to import:\n• \(newCount) new apps will be added\n• \(updateCount) existing apps will be replaced")
            
            // Add details about apps with paths
            let appsWithPaths = newApps.filter { !$0.configPaths.isEmpty }
            if !appsWithPaths.isEmpty {
                detailMessage += "\n\n" + String(localized: "Import_Apps_With_Paths")
                for app in appsWithPaths.prefix(5) {
                    detailMessage += "\n• \(app.name): \(String(localized: "Import_Path_Count", defaultValue: "\(app.configPaths.count) path(s)"))"
                }
                if appsWithPaths.count > 5 {
                    detailMessage += "\n• ..."
                }
            }
            
            alert.informativeText = detailMessage
            
            alert.addButton(withTitle: String(localized: "Import_Proceed"))
            alert.addButton(withTitle: String(localized: "Common_Cancel"))
            
            continuation.resume(returning: alert.runModal() == .alertFirstButtonReturn)
        }
    }
    
    private func showImportResult(_ result: MergeResult) async {
        var message = String(localized: "Import_Result", defaultValue: "Import completed:\n• Added: \(result.added) apps\n• Replaced: \(result.updated) apps\n• Skipped: \(result.skipped) apps")
        
        if result.updated > 0 {
            message += "\n\n" + String(localized: "Import_Update_Complete")
        }
        
        await showSuccessAlert(message: message)
    }
    
    private func showSuccessAlert(message: String) async {
        await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText = String(localized: "Success")
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.runModal()
            continuation.resume()
        }
    }
    
    private func showErrorAlert(message: String, informativeText: String) async {
        await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText = message
            alert.informativeText = informativeText
            alert.alertStyle = .warning
            alert.runModal()
            continuation.resume()
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
            return String(localized: "Import_Error_Version")
        case .invalidFormat:
            return String(localized: "Import_Error_Format")
        }
    }
}
