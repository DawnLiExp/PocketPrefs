//
//  UserConfigStore.swift
//  PocketPrefs
//
//  Persistent storage for user-added custom applications
//

import Foundation
import os.log

// MARK: - Change Events

enum UserConfigEvent: Sendable {
    case appAdded(AppConfig)
    case appUpdated(AppConfig)
    case appsRemoved(Set<UUID>)
    case batchUpdated([AppConfig])
}

// MARK: - User Config Store

@MainActor
final class UserConfigStore: ObservableObject {
    static let shared = UserConfigStore()
    
    @Published var customApps: [AppConfig] = []
    
    private let logger = Logger(subsystem: "com.pocketprefs", category: "UserConfigStore")
    private let storageURL: URL
    private var continuations: [UUID: AsyncStream<UserConfigEvent>.Continuation] = [:]
    
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
        
        storageURL = appDir.appendingPathComponent("custom_apps.json")
        loadCustomApps()
    }
    
    deinit {
        continuations.values.forEach { $0.finish() }
    }
    
    // MARK: - Event Broadcasting
    
    func subscribe() -> AsyncStream<UserConfigEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<UserConfigEvent>.makeStream(
            bufferingPolicy: .unbounded,
        )
        
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.continuations.removeValue(forKey: id)
                self?.logger.debug("Event subscriber unregistered: \(id)")
            }
        }
        
        continuations[id] = continuation
        logger.debug("Event subscriber registered: \(id)")
        
        return stream
    }
    
    private func broadcast(_ event: UserConfigEvent) {
        logger.debug("Broadcasting event to \(self.continuations.count) subscribers")
        continuations.values.forEach { $0.yield(event) }
    }
    
    // MARK: - Storage Operations
    
    private func loadCustomApps() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            logger.info("No custom apps file found")
            return
        }
        
        do {
            let data = try Data(contentsOf: storageURL)
            var apps = try JSONDecoder().decode([AppConfig].self, from: data)
            
            // Ensure all user-added apps have createdAt set
            for index in apps.indices where apps[index].isUserAdded {
                if apps[index].createdAt == Date(timeIntervalSince1970: 0) {
                    apps[index].createdAt = Date()
                }
            }
            
            customApps = apps
            logger.info("Loaded \(self.customApps.count) custom apps")
        } catch {
            logger.error("Failed to load custom apps: \(error.localizedDescription)")
        }
    }
    
    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(customApps)
            try data.write(to: storageURL)
            logger.debug("Saved \(self.customApps.count) custom apps")
        } catch {
            logger.error("Failed to save custom apps: \(error.localizedDescription)")
        }
    }
    
    // MARK: - App Management
    
    func addApp(_ app: AppConfig) {
        var newApp = app
        newApp.isUserAdded = true
        newApp.category = .custom
        newApp.createdAt = Date()
        
        customApps.append(newApp)
        save()
        broadcast(.appAdded(newApp))
        logger.info("Added app: \(newApp.name)")
    }
    
    func updateApp(_ app: AppConfig) {
        guard let index = customApps.firstIndex(where: { $0.id == app.id }) else {
            logger.warning("App not found for update: \(app.id)")
            return
        }
        
        customApps[index] = app
        save()
        broadcast(.appUpdated(app))
        logger.info("Updated app: \(app.name)")
    }
    
    func removeApps(_ appIds: Set<UUID>) {
        guard !appIds.isEmpty else { return }
        
        let countBefore = customApps.count
        customApps.removeAll { appIds.contains($0.id) }
        let removed = countBefore - customApps.count
        
        save()
        broadcast(.appsRemoved(appIds))
        logger.info("Removed \(removed) apps")
    }
    
    func batchUpdate(_ apps: [AppConfig]) {
        customApps = apps.map { app in
            var modifiedApp = app
            modifiedApp.isUserAdded = true
            modifiedApp.category = .custom
            // Preserve existing createdAt if available, otherwise set current time
            if modifiedApp.createdAt == Date(timeIntervalSince1970: 0) {
                modifiedApp.createdAt = Date()
            }
            return modifiedApp
        }
        save()
        broadcast(.batchUpdated(customApps))
        logger.info("Batch updated \(self.customApps.count) apps")
    }
    
    // MARK: - Queries
    
    func bundleIdExists(_ bundleId: String) -> Bool {
        customApps.contains { $0.bundleId == bundleId }
    }
}
