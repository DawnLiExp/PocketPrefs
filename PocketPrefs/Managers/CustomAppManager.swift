//
//  CustomAppManager.swift
//  PocketPrefs
//
//  Business logic for managing custom applications
//

import AppKit
@preconcurrency import Combine
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
    
    private var storeObserver: AnyCancellable?
    
    init() {
        loadCustomApps()
        observeStore()
    }
    
    // AnyCancellable automatically cancels on dealloc, no explicit deinit needed
    
    // MARK: - Store Observation
    
    private func observeStore() {
        storeObserver = userStore.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    // Brief delay to ensure store update completes
                    try? await Task.sleep(for: .milliseconds(10))
                    self?.syncFromStore()
                }
            }
    }
    
    private func syncFromStore() {
        let newApps = userStore.customApps
        let oldIds = Set(customApps.map(\.id))
        let newIds = Set(newApps.map(\.id))
        
        // Detect newly added apps
        let addedIds = newIds.subtracting(oldIds)
        if let newAppId = addedIds.first,
           let newApp = newApps.first(where: { $0.id == newAppId })
        {
            selectedApp = newApp
            logger.info("Auto-selected newly added app: \(newApp.name)")
        }
        
        // Detect removed apps
        let removedIds = oldIds.subtracting(newIds)
        if let selectedId = selectedApp?.id, removedIds.contains(selectedId) {
            selectedApp = nil
            logger.info("Cleared selection for removed app")
        }
        
        // Update app list
        customApps = newApps
        
        // Clean up selection IDs
        selectedAppIds = selectedAppIds.intersection(newIds)
        
        logger.info("Synced \(newApps.count) apps from store")
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
        
        logger.info("Loaded \(self.customApps.count) custom apps")
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
