//
//  UserConfigStore.swift
//  PocketPrefs
//
//  Persistent storage for user-added custom applications
//

import Foundation
import os.log

@MainActor
class UserConfigStore: ObservableObject {
    static let shared = UserConfigStore()
    
    @Published var customApps: [AppConfig] = []
    
    private let logger = Logger(subsystem: "com.pocketprefs", category: "UserConfigStore")
    private let storageURL: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("PocketPrefs", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appDir,
                                                withIntermediateDirectories: true)
        
        self.storageURL = appDir.appendingPathComponent("custom_apps.json")
        
        // Load existing custom apps
        loadCustomApps()
    }
    
    // Load custom apps from storage
    private func loadCustomApps() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            logger.info("No custom apps file found, starting fresh")
            return
        }
        
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            customApps = try decoder.decode([AppConfig].self, from: data)
            logger.info("Loaded \(self.customApps.count) custom apps")
        } catch {
            logger.error("Failed to load custom apps: \(error)")
        }
    }
    
    // Save custom apps to storage
    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(customApps)
            try data.write(to: storageURL)
            logger.info("Saved \(self.customApps.count) custom apps")
        } catch {
            logger.error("Failed to save custom apps: \(error)")
        }
    }
    
    // Add a new custom app
    func addApp(_ app: AppConfig) {
        var newApp = app
        newApp.isUserAdded = true
        newApp.category = .custom
        customApps.append(newApp)
        save()
        
        // Notify BackupManager to reload
        NotificationCenter.default.post(name: .customAppsChanged, object: nil)
    }
    
    // Update an existing app
    func updateApp(_ app: AppConfig) {
        if let index = customApps.firstIndex(where: { $0.id == app.id }) {
            customApps[index] = app
            save()
            NotificationCenter.default.post(name: .customAppsChanged, object: nil)
        }
    }
    
    // Remove apps
    func removeApps(_ appIds: Set<UUID>) {
        customApps.removeAll { appIds.contains($0.id) }
        save()
        NotificationCenter.default.post(name: .customAppsChanged, object: nil)
    }
    
    // Check if bundle ID already exists
    func bundleIdExists(_ bundleId: String) -> Bool {
        customApps.contains { $0.bundleId == bundleId }
    }
}

// Notification for custom apps changes
extension Notification.Name {
    static let customAppsChanged = Notification.Name("customAppsChanged")
}
