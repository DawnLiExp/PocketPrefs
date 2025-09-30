//
//  CustomAppManager.swift
//  PocketPrefs
//
//  Business logic for managing custom applications
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
        subscribeToEvents()
    }
    
    deinit {
        eventTask?.cancel()
    }
    
    private func subscribeToEvents() {
        eventTask?.cancel()
        eventTask = Task { [weak self] in
            guard let self else { return }
            
            for await event in userStore.events {
                guard !Task.isCancelled else { break }
                
                switch event {
                case .appAdded(let app):
                    await self.handleAppAdded(app)
                case .appUpdated(let app):
                    await self.handleAppUpdated(app)
                case .appsRemoved(let ids):
                    await self.handleAppsRemoved(ids)
                case .batchUpdated:
                    await self.handleBatchUpdate()
                case .appsChanged:
                    // Legacy support - shouldn't occur with new design
                    await self.handleBatchUpdate()
                }
            }
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleAppAdded(_ app: AppConfig) async {
        // Add to local array
        if !customApps.contains(where: { $0.id == app.id }) {
            customApps.append(app)
        }
        // Select newly added app
        selectedApp = app
        objectWillChange.send()
    }
    
    private func handleAppUpdated(_ app: AppConfig) async {
        // Update local state immediately
        if let index = customApps.firstIndex(where: { $0.id == app.id }) {
            customApps[index] = app
            if selectedApp?.id == app.id {
                selectedApp = app
            }
            objectWillChange.send()
        }
    }
    
    private func handleAppsRemoved(_ ids: Set<UUID>) async {
        // Clear selection if removed
        if let selectedId = selectedApp?.id,
           ids.contains(selectedId)
        {
            selectedApp = nil
        }
        
        // Remove from local array
        customApps.removeAll { ids.contains($0.id) }
        
        // Clean up selected IDs
        selectedAppIds = selectedAppIds.subtracting(ids)
        
        objectWillChange.send()
    }
    
    private func handleBatchUpdate() async {
        // Full reload from store
        loadCustomApps()
    }
    
    // MARK: - App Management
    
    func loadCustomApps() {
        customApps = userStore.customApps
        
        // Update selected app if it still exists
        if let currentSelectedId = selectedApp?.id,
           let updatedApp = customApps.first(where: { $0.id == currentSelectedId })
        {
            selectedApp = updatedApp
        } else {
            selectedApp = nil
        }
        
        // Clean up selected IDs
        let currentAppIds = Set(customApps.map(\.id))
        selectedAppIds = selectedAppIds.intersection(currentAppIds)
        
        objectWillChange.send()
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
            logger.warning("App with bundle ID \(app.bundleId) already exists")
            return
        }
        
        userStore.addApp(app)
    }
    
    func updateApp(_ app: AppConfig) {
        userStore.updateApp(app)
    }
    
    func removeSelectedApps() {
        userStore.removeApps(selectedAppIds)
        selectedAppIds.removeAll()
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
    
    func selectAll() {
        selectedAppIds = Set(customApps.map(\.id))
    }
    
    func deselectAll() {
        selectedAppIds.removeAll()
    }
    
    // MARK: - Validation
    
    func isValidBundleId(_ bundleId: String) -> Bool {
        guard !bundleId.isEmpty else { return false }
        
        // Support flexible formats
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
