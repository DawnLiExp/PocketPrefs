//
//  UserConfigStore.swift
//  PocketPrefs
//
//  Persistent storage for user-added custom applications
//

import Foundation
import os.log

// MARK: - Change Event

enum UserConfigEvent: Sendable {
    case appsChanged([AppConfig])
    case appAdded(AppConfig)
    case appUpdated(AppConfig)
    case appsRemoved(Set<UUID>)
    case batchUpdated([AppConfig]) // For import operations
}

// MARK: - User Config Store

@MainActor
final class UserConfigStore: ObservableObject {
    static let shared = UserConfigStore()
    
    @Published var customApps: [AppConfig] = []
    
    private let logger = Logger(subsystem: "com.pocketprefs", category: "UserConfigStore")
    private let storageURL: URL
    
    // AsyncStream for broadcasting changes
    private var continuation: AsyncStream<UserConfigEvent>.Continuation?
    let events: AsyncStream<UserConfigEvent>
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("PocketPrefs", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appDir,
                                                 withIntermediateDirectories: true)
        
        self.storageURL = appDir.appendingPathComponent("custom_apps.json")
        
        // Initialize async stream
        let (stream, continuation) = AsyncStream<UserConfigEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(1),
        )
        self.events = stream
        self.continuation = continuation
        
        // Load existing custom apps
        loadCustomApps()
    }
    
    deinit {
        continuation?.finish()
    }
    
    // MARK: - Storage Operations
    
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
    
    // MARK: - App Management
    
    func addApp(_ app: AppConfig) {
        var newApp = app
        newApp.isUserAdded = true
        newApp.category = .custom
        customApps.append(newApp)
        save()
        
        // Only broadcast specific event
        continuation?.yield(.appAdded(newApp))
    }
    
    func updateApp(_ app: AppConfig) {
        guard let index = customApps.firstIndex(where: { $0.id == app.id }) else { return }
        
        customApps[index] = app
        save()
        
        // Only broadcast specific event
        continuation?.yield(.appUpdated(app))
    }
    
    func removeApps(_ appIds: Set<UUID>) {
        guard !appIds.isEmpty else { return }
        
        customApps.removeAll { appIds.contains($0.id) }
        save()
        
        // Only broadcast specific event
        continuation?.yield(.appsRemoved(appIds))
    }
    
    func batchUpdate(_ apps: [AppConfig]) {
        customApps = apps.map { app in
            var modifiedApp = app
            modifiedApp.isUserAdded = true
            modifiedApp.category = .custom
            return modifiedApp
        }
        save()
        
        // Broadcast batch update event
        continuation?.yield(.batchUpdated(customApps))
    }
    
    // MARK: - Queries
    
    func bundleIdExists(_ bundleId: String) -> Bool {
        customApps.contains { $0.bundleId == bundleId }
    }
}
