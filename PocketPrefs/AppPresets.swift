//
//  AppPresets.swift
//  PocketPrefs
//
//  Created by Me2 on 2025/9/17.
//

import AppKit
import Foundation
import SwiftUI

// MARK: - Data Models

struct AppConfig: Identifiable, Codable, Sendable {
    var id = UUID()
    let name: String
    let bundleId: String
    var configPaths: [String]
    var isSelected: Bool = false
    var isInstalled: Bool = true
    var category: AppCategory = .development
    
    // Custom CodingKeys to exclude non-persistent properties
    enum CodingKeys: String, CodingKey {
        case name, bundleId, configPaths, category
    }
}

// MARK: - Backup Related Models

struct BackupInfo: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let name: String
    let date: Date
    var apps: [BackupAppInfo] = []
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: BackupInfo, rhs: BackupInfo) -> Bool {
        lhs.id == rhs.id
    }
}

struct BackupAppInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let bundleId: String
    let configPaths: [String]
    var isCurrentlyInstalled: Bool
    var isSelected: Bool
    var icon: NSImage?
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: BackupAppInfo, rhs: BackupAppInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - App Category

enum AppCategory: String, Codable, CaseIterable, Sendable { // Added Sendable
    case development = "Development"
    case productivity = "Productivity"
    case system = "System"
    case terminal = "Terminal"
    case design = "Design"
    
    var icon: String {
        switch self {
        case .development: return "hammer.fill"
        case .productivity: return "briefcase.fill"
        case .system: return "gear"
        case .terminal: return "terminal.fill"
        case .design: return "paintbrush.fill"
        }
    }
    
    // Default icon for category
    var defaultAppIcon: NSImage {
        return NSImage(systemSymbolName: icon, accessibilityDescription: nil) ?? NSImage()
    }
}

// MARK: - Icon Helper

@MainActor
final class IconHelper {
    static let shared = IconHelper()
    private let iconCache = NSCache<NSString, NSImage>()
    
    private init() {
        iconCache.countLimit = 100
    }
    
    // Get icon for bundle ID with caching
    func getIcon(for bundleId: String, category: AppCategory = .system) -> NSImage {
        // Check cache first
        if let cached = iconCache.object(forKey: bundleId as NSString) {
            return cached
        }
        
        // Fetch icon
        let icon = fetchIcon(for: bundleId, category: category)
        iconCache.setObject(icon, forKey: bundleId as NSString)
        return icon
    }
    
    private func fetchIcon(for bundleId: String, category: AppCategory) -> NSImage {
        // Handle special cases for terminal tools
        switch bundleId {
        case "oh-my-zsh":
            return createTerminalIcon(with: "Z")
        case "git":
            return createTerminalIcon(with: "G")
        case "ssh":
            return createTerminalIcon(with: "S")
        case "homebrew":
            return createTerminalIcon(with: "H")
        default:
            // Try to get app icon from bundle
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
               let bundle = Bundle(url: appURL),
               let iconFile = bundle.infoDictionary?["CFBundleIconFile"] as? String
            {
                // Try different icon file extensions
                let iconName = iconFile.replacingOccurrences(of: ".icns", with: "")
                if let icon = bundle.image(forResource: iconName) {
                    return resizedIcon(icon)
                }
            }
            
            // Try to get icon from NSWorkspace
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                let icon = NSWorkspace.shared.icon(forFile: appURL.path)
                return resizedIcon(icon)
            }
            
            // Return category default icon
            return category.defaultAppIcon
        }
    }
    
    // Create custom icon for terminal tools
    private func createTerminalIcon(with letter: String) -> NSImage {
        let size = NSSize(width: 32, height: 32)
        let image = NSImage(size: size, flipped: false) { rect in
            // Dark background
            NSColor.darkGray.setFill()
            let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
            path.fill()
            
            // Terminal prompt style text
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .bold),
                .foregroundColor: NSColor.systemGreen,
                .paragraphStyle: paragraphStyle
            ]
            
            let text = ">_\(letter)"
            let textSize = text.size(withAttributes: attributes)
            let textRect = NSRect(
                x: (rect.width - textSize.width) / 2,
                y: (rect.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
            
            return true
        }
        
        return image
    }
    
    // Resize icon to standard size
    private func resizedIcon(_ icon: NSImage, size: NSSize = NSSize(width: 32, height: 32)) -> NSImage {
        let resized = NSImage(size: size)
        resized.lockFocus()
        icon.draw(in: NSRect(origin: .zero, size: size),
                  from: NSRect(origin: .zero, size: icon.size),
                  operation: .sourceOver,
                  fraction: 1.0)
        resized.unlockFocus()
        return resized
    }
}

// MARK: - Preset App Configurations

extension AppConfig {
    @MainActor
    static let presetConfigs: [AppConfig] = [
        // Development Tools
        AppConfig(name: "Visual Studio Code", bundleId: "com.microsoft.VSCode", configPaths: [
            "~/Library/Application Support/Code",
            "~/.vscode"
        ], category: .development),
        
        AppConfig(name: "Xcode", bundleId: "com.apple.dt.Xcode", configPaths: [
            "~/Library/Developer/Xcode/UserData",
            "~/Library/Preferences/com.apple.dt.Xcode.plist"
        ], category: .development),
        
        AppConfig(name: "Kaleidoscope", bundleId: "com.blackpixel.kaleidoscope", configPaths: [
            "~/Library/Application Support/Kaleidoscope",
            "~/Library/Preferences/com.blackpixel.kaleidoscope.plist"
        ], category: .development),
        
        // Terminal Tools
        AppConfig(name: "iTerm2", bundleId: "com.googlecode.iterm2", configPaths: [
            "~/Library/Preferences/com.googlecode.iterm2.plist",
            "~/Library/Application Support/iTerm2"
        ], category: .terminal),
        
        AppConfig(name: "Oh My Zsh", bundleId: "oh-my-zsh", configPaths: [
            "~/.zshrc",
            "~/.oh-my-zsh/custom"
        ], category: .terminal),
        
        AppConfig(name: "Git", bundleId: "git", configPaths: [
            "~/.gitconfig",
            "~/.gitignore_global"
        ], category: .terminal),
        
        AppConfig(name: "SSH", bundleId: "ssh", configPaths: [
            "~/.ssh/config"
        ], category: .terminal),
        
        AppConfig(name: "Homebrew", bundleId: "homebrew", configPaths: [
            "~/.Brewfile",
            "/usr/local/etc"
        ], category: .terminal),
        
        AppConfig(name: "Transmit", bundleId: "com.panic.Transmit", configPaths: [
            "~/Library/Application Support/Transmit",
            "~/Library/Preferences/com.panic.Transmit.plist"
        ], category: .productivity),
        
        AppConfig(name: "Pixelmator Pro", bundleId: "com.pixelmatorteam.pixelmator.x", configPaths: [
            "~/Library/Application Support/Pixelmator Pro",
            "~/Library/Preferences/com.pixelmatorteam.pixelmator.x.plist"
        ], category: .design)
    ]
}

// MARK: - Backup Manager

@MainActor
class BackupManager: ObservableObject {
    @Published var apps: [AppConfig] = []
    @Published var isProcessing = false
    @Published var statusMessage = ""
    @Published var currentProgress: Double = 0.0
    
    // Restore mode related
    @Published var availableBackups: [BackupInfo] = []
    @Published var selectedBackup: BackupInfo?
    
    private let backupBaseDir = NSHomeDirectory() + "/Documents/PocketPrefsBackups"
    private let fileManager = FileManager.default
    private let iconHelper = IconHelper.shared
    
    init() {
        loadApps()
        scanBackups()
    }
    
    func loadApps() {
        // Load preset configs, check installation status
        apps = AppConfig.presetConfigs.map { config in
            var app = config
            app.isInstalled = checkIfAppInstalled(bundleId: config.bundleId)
            // Default select installed apps
            app.isSelected = app.isInstalled
            return app
        }
    }
    
    // Get icon for an app (called from UI)
    func getIcon(for app: AppConfig) -> NSImage {
        return iconHelper.getIcon(for: app.bundleId, category: app.category)
    }
    
    // MARK: - Backup Scanning
    
    func scanBackups() {
        availableBackups = []
        
        // Ensure backup directory exists
        if !fileManager.fileExists(atPath: backupBaseDir) {
            try? fileManager.createDirectory(atPath: backupBaseDir, withIntermediateDirectories: true)
            return
        }
        
        do {
            let backupDirs = try fileManager.contentsOfDirectory(atPath: backupBaseDir)
                .filter { $0.hasPrefix("Backup_") }
                .sorted { $0 > $1 } // Sort by time descending
            
            for dirName in backupDirs {
                let backupPath = "\(backupBaseDir)/\(dirName)"
                var backup = BackupInfo(
                    path: backupPath,
                    name: dirName,
                    date: parseDateFromBackupName(dirName) ?? Date()
                )
                
                // Scan apps in backup
                backup.apps = scanAppsInBackup(at: backupPath)
                
                if !backup.apps.isEmpty {
                    availableBackups.append(backup)
                }
            }
            
            // Select the latest backup by default
            if let firstBackup = availableBackups.first {
                selectBackup(firstBackup)
            }
        } catch {
            print("Failed to scan backups: \(error)")
        }
    }
    
    func scanAppsInBackup(at path: String) -> [BackupAppInfo] {
        var apps: [BackupAppInfo] = []
        
        do {
            let appDirs = try fileManager.contentsOfDirectory(atPath: path)
                .filter { !$0.hasPrefix(".") } // Ignore hidden files
            
            for appDir in appDirs {
                let appPath = "\(path)/\(appDir)"
                let configPath = "\(appPath)/app_config.json"
                
                // Read app configuration
                if fileManager.fileExists(atPath: configPath) {
                    do {
                        let configData = try Data(contentsOf: URL(fileURLWithPath: configPath))
                        let appConfig = try JSONDecoder().decode(AppConfig.self, from: configData)
                        
                        let backupApp = BackupAppInfo(
                            name: appConfig.name,
                            path: appPath,
                            bundleId: appConfig.bundleId,
                            configPaths: appConfig.configPaths,
                            isCurrentlyInstalled: checkIfAppInstalled(bundleId: appConfig.bundleId),
                            isSelected: checkIfAppInstalled(bundleId: appConfig.bundleId), // Default select installed
                            icon: iconHelper.getIcon(for: appConfig.bundleId, category: appConfig.category)
                        )
                        apps.append(backupApp)
                    } catch {
                        print("Failed to read app config: \(appDir)")
                    }
                }
            }
        } catch {
            print("Failed to scan backup apps: \(error)")
        }
        
        return apps
    }
    
    private func parseDateFromBackupName(_ name: String) -> Date? {
        // Parse "Backup_2025-9-18, 1-26 AM" format
        let dateString = name.replacingOccurrences(of: "Backup_", with: "")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-M-d, h-mm a"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.date(from: dateString)
    }
    
    func selectBackup(_ backup: BackupInfo) {
        selectedBackup = backup
    }
    
    func toggleRestoreSelection(for app: BackupAppInfo) {
        guard let currentBackup = selectedBackup,
              let backupIndex = availableBackups.firstIndex(where: { $0.id == currentBackup.id }),
              let appIndex = availableBackups[backupIndex].apps.firstIndex(where: { $0.id == app.id })
        else {
            return
        }
        
        // Toggle the selection state
        availableBackups[backupIndex].apps[appIndex].isSelected.toggle()
               
        // Create a new BackupInfo instance to trigger SwiftUI update
        let updatedBackup = availableBackups[backupIndex]
               
        // Force SwiftUI to recognize the change by reassigning
        selectedBackup = nil
        selectedBackup = updatedBackup
        
        // Trigger objectWillChange manually to ensure UI updates
        objectWillChange.send()
    }
    
    // Alternative implementation if the above doesn't work
    // This creates a completely new backup object to ensure updates
    func toggleRestoreSelectionAlternative(for app: BackupAppInfo) {
        guard let currentBackup = selectedBackup else { return }
        
        // Find and update the app in the backup
        var updatedApps = currentBackup.apps
        if let appIndex = updatedApps.firstIndex(where: { $0.id == app.id }) {
            updatedApps[appIndex].isSelected.toggle()
        }
        
        // Create new backup with updated apps
        var newBackup = BackupInfo(
            path: currentBackup.path,
            name: currentBackup.name,
            date: currentBackup.date
        )
        newBackup.apps = updatedApps
        
        // Update in availableBackups
        if let backupIndex = availableBackups.firstIndex(where: { $0.id == currentBackup.id }) {
            availableBackups[backupIndex] = newBackup
            selectedBackup = newBackup
        }
        
        // Force update
        objectWillChange.send()
    }
    
    func performSelectiveRestore() {
        guard let backup = selectedBackup else { return }
        
        isProcessing = true
        currentProgress = 0.0
        statusMessage = "Starting restore..."
        
        let selectedApps = backup.apps.filter { $0.isSelected }
        var successCount = 0
        var failedApps: [String] = []
        let totalApps = Double(selectedApps.count)
        
        for (index, app) in selectedApps.enumerated() {
            currentProgress = Double(index) / totalApps
            
            do {
                // Restore config files
                for originalPath in app.configPaths {
                    let expandedPath = NSString(string: originalPath).expandingTildeInPath
                    let fileName = URL(fileURLWithPath: expandedPath).lastPathComponent
                    let sourcePath = "\(app.path)/\(fileName)"
                    
                    if fileManager.fileExists(atPath: sourcePath) {
                        // Backup existing file
                        if fileManager.fileExists(atPath: expandedPath) {
                            let backupPath = expandedPath + ".pocketprefs_backup"
                            try? fileManager.removeItem(atPath: backupPath)
                            try? fileManager.moveItem(atPath: expandedPath, toPath: backupPath)
                        }
                        
                        // Ensure destination directory exists
                        let destDir = URL(fileURLWithPath: expandedPath).deletingLastPathComponent().path
                        try fileManager.createDirectory(atPath: destDir, withIntermediateDirectories: true)
                        
                        // Restore file
                        try copyItem(from: sourcePath, to: expandedPath)
                    }
                }
                successCount += 1
            } catch {
                failedApps.append(app.name)
                print("Failed to restore \(app.name): \(error)")
            }
        }
        
        currentProgress = 1.0
        
        if failedApps.isEmpty {
            statusMessage = "✅ Restore complete! Successfully restored \(successCount) app configs"
        } else {
            statusMessage = "⚠️ Restore complete. Success: \(successCount), Failed: \(failedApps.joined(separator: ", "))"
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isProcessing = false
            self.currentProgress = 0.0
        }
    }
    
    private func checkIfAppInstalled(bundleId: String) -> Bool {
        // For command-line tools, check if config files exist
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
            // Check if app is installed
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
        }
    }
    
    func toggleSelection(for app: AppConfig) {
        if let index = apps.firstIndex(where: { $0.id == app.id }) {
            apps[index].isSelected.toggle()
        }
    }
    
    func selectAll() {
        for index in apps.indices {
            apps[index].isSelected = true
        }
    }
    
    func deselectAll() {
        for index in apps.indices {
            apps[index].isSelected = false
        }
    }
    
    func performBackup() {
        isProcessing = true
        currentProgress = 0.0
        statusMessage = "Starting backup..."
        
        let selectedApps = apps.filter { $0.isSelected && $0.isInstalled }
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let backupDir = "\(backupBaseDir)/Backup_\(timestamp)"
        
        // Create backup directory
        do {
            try fileManager.createDirectory(atPath: backupDir, withIntermediateDirectories: true)
        } catch {
            statusMessage = "Failed to create backup directory: \(error.localizedDescription)"
            isProcessing = false
            return
        }
        
        var successCount = 0
        var failedApps: [String] = []
        let totalApps = Double(selectedApps.count)
        
        for (index, app) in selectedApps.enumerated() {
            currentProgress = Double(index) / totalApps
            
            let appBackupDir = "\(backupDir)/\(app.name.replacingOccurrences(of: " ", with: "_"))"
            do {
                try fileManager.createDirectory(atPath: appBackupDir, withIntermediateDirectories: true)
                
                for path in app.configPaths {
                    let expandedPath = NSString(string: path).expandingTildeInPath
                    
                    if fileManager.fileExists(atPath: expandedPath) {
                        let destPath = "\(appBackupDir)/\(URL(fileURLWithPath: expandedPath).lastPathComponent)"
                        try copyItem(from: expandedPath, to: destPath)
                    }
                }
                
                // Save app config info
                let configData = try JSONEncoder().encode(app)
                try configData.write(to: URL(fileURLWithPath: "\(appBackupDir)/app_config.json"))
                
                successCount += 1
            } catch {
                failedApps.append(app.name)
                print("Failed to backup \(app.name): \(error)")
            }
        }
        
        currentProgress = 1.0
        
        if failedApps.isEmpty {
            statusMessage = "✅ Backup complete! Successfully backed up \(successCount) apps"
        } else {
            statusMessage = "⚠️ Backup complete. Success: \(successCount), Failed: \(failedApps.joined(separator: ", "))"
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isProcessing = false
            self.currentProgress = 0.0
        }
    }
    
    func performRestore(from backupPath: String) {
        isProcessing = true
        currentProgress = 0.0
        statusMessage = "Starting restore..."
        
        let backupURL = URL(fileURLWithPath: backupPath)
        var successCount = 0
        var failedApps: [String] = []
        
        do {
            let appDirs = try fileManager.contentsOfDirectory(at: backupURL,
                                                              includingPropertiesForKeys: nil)
                .filter { $0.hasDirectoryPath }
            
            let totalApps = Double(appDirs.count)
            
            for (index, appDir) in appDirs.enumerated() {
                currentProgress = Double(index) / totalApps
                
                let configPath = appDir.appendingPathComponent("app_config.json")
                
                if fileManager.fileExists(atPath: configPath.path) {
                    do {
                        let configData = try Data(contentsOf: configPath)
                        let appConfig = try JSONDecoder().decode(AppConfig.self, from: configData)
                        
                        // Restore config files
                        for originalPath in appConfig.configPaths {
                            let expandedPath = NSString(string: originalPath).expandingTildeInPath
                            let fileName = URL(fileURLWithPath: expandedPath).lastPathComponent
                            let sourcePath = appDir.appendingPathComponent(fileName).path
                            
                            if fileManager.fileExists(atPath: sourcePath) {
                                // Backup existing file
                                if fileManager.fileExists(atPath: expandedPath) {
                                    let backupPath = expandedPath + ".pocketprefs_backup"
                                    try? fileManager.removeItem(atPath: backupPath)
                                    try? fileManager.moveItem(atPath: expandedPath, toPath: backupPath)
                                }
                                
                                // Restore file
                                let destDir = URL(fileURLWithPath: expandedPath).deletingLastPathComponent().path
                                try fileManager.createDirectory(atPath: destDir, withIntermediateDirectories: true)
                                try copyItem(from: sourcePath, to: expandedPath)
                            }
                        }
                        successCount += 1
                    } catch {
                        failedApps.append(appDir.lastPathComponent)
                        print("Failed to restore \(appDir.lastPathComponent): \(error)")
                    }
                }
            }
            
            currentProgress = 1.0
        } catch {
            statusMessage = "Failed to read backup directory: \(error.localizedDescription)"
            isProcessing = false
            return
        }
        
        if failedApps.isEmpty {
            statusMessage = "✅ Restore complete! Successfully restored \(successCount) app configs"
        } else {
            statusMessage = "⚠️ Restore complete. Success: \(successCount), Failed: \(failedApps.joined(separator: ", "))"
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isProcessing = false
            self.currentProgress = 0.0
        }
    }
    
    private func copyItem(from source: String, to destination: String) throws {
        try? fileManager.removeItem(atPath: destination)
        try fileManager.copyItem(atPath: source, toPath: destination)
    }
    
    // Get apps by category
    func apps(for category: AppCategory) -> [AppConfig] {
        apps.filter { $0.category == category }
    }
}
