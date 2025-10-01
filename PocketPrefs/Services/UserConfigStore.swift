//
//  UserConfigStore.swift
//  PocketPrefs
//
//  Persistent storage for user-added custom applications with AsyncStream events
//

import Foundation
import os.log

// MARK: - Change Events

enum UserConfigEvent: Sendable {
    case appAdded(AppConfig)
    case appUpdated(AppConfig)
    case appsRemoved(Set<UUID>)
    case batchUpdated([AppConfig])
    case appsChanged([AppConfig])
}

// MARK: - User Config Store

@MainActor
final class UserConfigStore: ObservableObject {
    static let shared = UserConfigStore()
    
    @Published var customApps: [AppConfig] = []
    
    private let logger = Logger(subsystem: "com.pocketprefs", category: "UserConfigStore")
    private let storageURL: URL
    
    private var continuation: AsyncStream<UserConfigEvent>.Continuation?
    let events: AsyncStream<UserConfigEvent>
    
    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
        ).first!
        let appDir = appSupport.appendingPathComponent("PocketPrefs", isDirectory: true)
        
        try? FileManager.default.createDirectory(
            at: appDir,
            withIntermediateDirectories: true,
        )
        
        self.storageURL = appDir.appendingPathComponent("custom_apps.json")
        
        let (stream, continuation) = AsyncStream<UserConfigEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(1),
        )
        self.events = stream
        self.continuation = continuation
        
        loadCustomApps()
    }
    
    deinit {
        continuation?.finish()
    }
    
    // MARK: - Storage Operations
    
    private func loadCustomApps() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            logger.info("No custom apps file, starting fresh")
            return
        }
        
        do {
            let data = try Data(contentsOf: storageURL)
            customApps = try JSONDecoder().decode([AppConfig].self, from: data)
            logger.info("Loaded \(self.customApps.count) custom apps")
        } catch {
            logger.error("Failed to load: \(error)")
        }
    }
    
    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(customApps)
            try data.write(to: storageURL)
            logger.info("Saved \(self.customApps.count) custom apps")
        } catch {
            logger.error("Failed to save: \(error)")
        }
    }
    
    // MARK: - App Management
    
    func addApp(_ app: AppConfig) {
        var newApp = app
        newApp.isUserAdded = true
        newApp.category = .custom
        customApps.append(newApp)
        save()
        
        continuation?.yield(.appAdded(newApp))
    }
    
    func updateApp(_ app: AppConfig) {
        guard let index = customApps.firstIndex(where: { $0.id == app.id }) else { return }
        
        customApps[index] = app
        save()
        
        continuation?.yield(.appUpdated(app))
    }
    
    func removeApps(_ appIds: Set<UUID>) {
        guard !appIds.isEmpty else { return }
        
        customApps.removeAll { appIds.contains($0.id) }
        save()
        
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
        
        continuation?.yield(.batchUpdated(customApps))
    }
    
    // MARK: - Queries
    
    func bundleIdExists(_ bundleId: String) -> Bool {
        customApps.contains { $0.bundleId == bundleId }
    }
}
