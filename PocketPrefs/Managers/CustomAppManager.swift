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
class CustomAppManager: ObservableObject {
    @Published var customApps: [AppConfig] = []
    @Published var selectedApp: AppConfig?
    @Published var selectedAppIds: Set<UUID> = []
    @Published var isAddingApp = false
    @Published var editingApp: AppConfig?
    
    private let logger = Logger(subsystem: "com.pocketprefs", category: "CustomAppManager")
    let userStore = UserConfigStore.shared
    private let fileOps = FileOperationService.shared
    
    init() {
        loadCustomApps()
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCustomAppsChanged),
            name: .customAppsChanged,
            object: nil
        )
    }
    
    @objc private func handleCustomAppsChanged() {
        Task { @MainActor in
            loadCustomApps()
        }
    }
    
    func loadCustomApps() {
        customApps = userStore.customApps
        
        // Force update selected app to trigger view refresh
        if let currentSelectedId = selectedApp?.id,
           let updatedApp = customApps.first(where: { $0.id == currentSelectedId })
        {
            // Temporarily clear and reset to force view update
            let tempApp = updatedApp
            selectedApp = nil
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_000_000)
                self.selectedApp = tempApp
            }
        } else {
            selectedApp = nil
        }
        
        // Clean up selected IDs if apps no longer exist
        let currentAppIds = Set(customApps.map { $0.id })
        selectedAppIds = selectedAppIds.intersection(currentAppIds)
        
        // Trigger UI update
        objectWillChange.send()
    }
    
    func createNewApp(name: String, bundleId: String) -> AppConfig {
        return AppConfig(
            name: name,
            bundleId: bundleId,
            configPaths: [],
            isSelected: true,
            isInstalled: true,
            category: .custom,
            isUserAdded: true
        )
    }
    
    func addApp(_ app: AppConfig) {
        guard !userStore.bundleIdExists(app.bundleId) else {
            logger.warning("App with bundle ID \(app.bundleId) already exists")
            return
        }
        
        userStore.addApp(app)
        loadCustomApps()
        
        // Select the newly added app
        selectedApp = customApps.last { $0.bundleId == app.bundleId }
    }
    
    func updateApp(_ app: AppConfig) {
        userStore.updateApp(app)
        
        // Update local array immediately for responsive UI
        if let index = customApps.firstIndex(where: { $0.id == app.id }) {
            customApps[index] = app
            // Force refresh selected app to trigger view updates
            if selectedApp?.id == app.id {
                selectedApp = app
            }
        }
        
        // Trigger save to persistent storage
        userStore.save()
    }
    
    func removeSelectedApps() {
        // Clear selected app if it's being removed
        if let selectedId = selectedApp?.id, selectedAppIds.contains(selectedId) {
            selectedApp = nil
        }
        
        userStore.removeApps(selectedAppIds)
        selectedAppIds.removeAll()
        loadCustomApps()
    }
    
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
    
    func toggleSelection(for appId: UUID) {
        if selectedAppIds.contains(appId) {
            selectedAppIds.remove(appId)
        } else {
            selectedAppIds.insert(appId)
        }
    }
    
    func selectAll() {
        selectedAppIds = Set(customApps.map { $0.id })
    }
    
    func deselectAll() {
        selectedAppIds.removeAll()
    }
    
    func isValidBundleId(_ bundleId: String) -> Bool {
        // Support flexible formats including simple names like "git", "ssh"
        if bundleId.isEmpty { return false }
        
        // Simple validation: starts with letter, allows letters, numbers, dots, hyphens
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
            case .file: return "doc.fill"
            case .directory: return "folder.fill"
            case .unknown: return "questionmark.circle"
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
