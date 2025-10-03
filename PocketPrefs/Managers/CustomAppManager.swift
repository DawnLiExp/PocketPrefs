//
//  CustomAppManager.swift
//  PocketPrefs
//
//  Custom app management with reliable event processing
//

import AppKit
import Foundation
import os.log

@MainActor
final class CustomAppManager: ObservableObject {
    @Published var customApps: [AppConfig] = []
    @Published var selectedApp: AppConfig?
    @Published var selectedAppIds: Set<UUID> = []
    @Published var isAddingApp = false
    @Published var editingApp: AppConfig?
    
    private let logger = Logger(subsystem: "com.pocketprefs", category: "CustomAppManager")
    let userStore = UserConfigStore.shared
    private let fileOps = FileOperationService.shared
    
    private var eventTask: Task<Void, Never>?
    
    init() {
        loadCustomApps()
        subscribeToStoreEvents()
    }
    
    deinit {
        eventTask?.cancel()
    }
    
    // MARK: - Event Subscription
    
    private func subscribeToStoreEvents() {
        eventTask?.cancel()
        eventTask = Task { [weak self] in
            guard let self else { return }
            
            for await event in userStore.events {
                guard !Task.isCancelled else { break }
                
                await self.handleStoreEvent(event)
                
                try? await Task.sleep(for: .milliseconds(10))
            }
        }
    }
    
    private func handleStoreEvent(_ event: UserConfigEvent) async {
        switch event {
        case .appAdded(let app):
            syncFromStore()
            selectedApp = app
            logger.info("Event: App added - \(app.name)")
            
        case .appsRemoved(let removedIds):
            if let selectedId = selectedApp?.id, removedIds.contains(selectedId) {
                selectedApp = nil
                logger.info("Event: Cleared selection for removed app")
            }
            syncFromStore()
            logger.info("Event: Apps removed - \(removedIds.count)")
            
        case .appUpdated(let app):
            if selectedApp?.id == app.id {
                selectedApp = app
            }
            syncFromStore()
            logger.info("Event: App updated - \(app.name)")
            
        case .batchUpdated, .appsChanged:
            syncFromStore()
            logger.info("Event: Batch update")
        }
        
        objectWillChange.send()
    }
    
    // MARK: - State Synchronization
    
    private func syncFromStore() {
        // Force new array instance to ensure @Published triggers
        customApps = Array(userStore.customApps)
        
        // Validate selections
        let validIds = Set(customApps.map(\.id))
        selectedAppIds.formIntersection(validIds)
        
        // Validate selected app
        if let currentSelectedId = selectedApp?.id {
            if let updatedApp = customApps.first(where: { $0.id == currentSelectedId }) {
                selectedApp = updatedApp
            } else {
                selectedApp = nil
            }
        }
        
        logger.debug("Synced: \(self.customApps.count) apps")
    }
    
    // MARK: - App Management
    
    func loadCustomApps() {
        syncFromStore()
        logger.info("Loaded \(self.customApps.count) custom apps")
    }
    
    func manualRefresh() {
        logger.info("Manual refresh triggered")
        syncFromStore()
        objectWillChange.send()
        logger.info("Manual refresh completed: \(self.customApps.count) apps")
    }
    
    func createNewApp(name: String, bundleId: String) -> AppConfig {
        AppConfig(
            name: name,
            bundleId: bundleId,
            configPaths: [],
            isSelected: false,
            isInstalled: true,
            category: .custom,
            isUserAdded: true,
        )
    }
    
    func addApp(_ app: AppConfig) {
        guard !userStore.bundleIdExists(app.bundleId) else {
            logger.warning("Bundle ID already exists: \(app.bundleId)")
            return
        }
        
        userStore.addApp(app)
        syncFromStore()
        objectWillChange.send()
    }
    
    func updateApp(_ app: AppConfig) {
        userStore.updateApp(app)
        syncFromStore()
        objectWillChange.send()
    }
    
    func removeSelectedApps() {
        userStore.removeApps(selectedAppIds)
        selectedAppIds.removeAll()
        syncFromStore()
        objectWillChange.send()
    }
    
    // MARK: - Path Management
    
    func addPath(to app: AppConfig, path: String) {
        var updatedApp = app
        if !updatedApp.configPaths.contains(path) {
            updatedApp.configPaths.append(path)
            updateApp(updatedApp)
        }
    }
    
    func removePath(from app: AppConfig, at index: Int) {
        guard index < app.configPaths.count else { return }
        
        var updatedApp = app
        updatedApp.configPaths.remove(at: index)
        updateApp(updatedApp)
    }
    
    func editPath(in app: AppConfig, at index: Int, newPath: String) {
        guard index < app.configPaths.count else { return }
        
        var updatedApp = app
        updatedApp.configPaths[index] = newPath
        updateApp(updatedApp)
    }
    
    // MARK: - Selection Management
    
    func toggleSelection(for appId: UUID) {
        if selectedAppIds.contains(appId) {
            selectedAppIds.remove(appId)
        } else {
            selectedAppIds.insert(appId)
        }
    }
    
    func selectAll() async {
        if customApps.count > 50 {
            try? await Task.sleep(for: .milliseconds(10))
        }
        selectedAppIds = Set(customApps.map(\.id))
    }
    
    func deselectAll() {
        selectedAppIds.removeAll()
    }
    
    // MARK: - Validation
    
    func isValidBundleId(_ bundleId: String) -> Bool {
        guard !bundleId.isEmpty else { return false }
        
        let pattern = "^[a-zA-Z][a-zA-Z0-9.-]*$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: bundleId.utf16.count)
        return regex?.firstMatch(in: bundleId, range: range) != nil
    }
    
    func pathExists(_ path: String) -> Bool {
        let expandedPath = NSString(string: path).expandingTildeInPath
        return FileManager.default.fileExists(atPath: expandedPath)
    }
    
    func getPathType(_ path: String) -> PathType {
        let expandedPath = NSString(string: path).expandingTildeInPath
        var isDirectory: ObjCBool = false
        
        if FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory) {
            return isDirectory.boolValue ? .directory : .file
        }
        
        return .unknown
    }
    
    enum PathType {
        case file
        case directory
        case unknown
        
        var icon: String {
            switch self {
            case .file: "doc.fill"
            case .directory: "folder.fill"
            case .unknown: "questionmark.circle"
            }
        }
    }
}
