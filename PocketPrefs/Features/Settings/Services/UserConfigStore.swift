//
//  UserConfigStore.swift
//  PocketPrefs
//
//  Persistent storage for user-added custom applications
//

import Foundation
import Observation
import os.log

// MARK: - Change Events

enum UserConfigEvent {
    case appAdded(AppConfig)
    case appUpdated(AppConfig)
    case appsRemoved(Set<String>)
    case batchUpdated([AppConfig])
}

// MARK: - User Config Store

@Observable
@MainActor
final class UserConfigStore {
    static let shared = UserConfigStore()
    
    private(set) var customApps: [AppConfig] = []
    private(set) var loadError: String?
    
    private let logger = Logger(subsystem: "com.me2.PocketPrefs", category: "UserConfigStore")
    private let storageURL: URL
    @ObservationIgnored
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

    // IMPORTANT: For testing only. Injects storageURL so tests never touch
    // the real Application Support directory and can be cleaned up after each run.
    init(storageURL: URL) {
        self.storageURL = storageURL
        loadCustomApps()
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
        do {
            let data = try Data(contentsOf: storageURL)
            customApps = try JSONDecoder().decode([AppConfig].self, from: data)
            logger.info("Loaded \(self.customApps.count) custom apps")
        } catch CocoaError.fileReadNoSuchFile {
            logger.info("No custom apps file found")
        } catch {
            loadError = "\(storageURL.path)\n\(error.localizedDescription)"
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
        guard loadError == nil else { return }
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
    
    func removeApps(_ appIds: Set<String>) {
        guard loadError == nil, !appIds.isEmpty else { return }
        
        let countBefore = customApps.count
        customApps.removeAll { appIds.contains($0.id) }
        let removed = countBefore - customApps.count
        
        save()
        broadcast(.appsRemoved(appIds))
        logger.info("Removed \(removed) apps")
    }
    
    func batchUpdate(_ apps: [AppConfig]) {
        guard loadError == nil else { return }
        customApps = apps.map { app in
            var modifiedApp = app
            modifiedApp.isUserAdded = true
            modifiedApp.category = .custom
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
