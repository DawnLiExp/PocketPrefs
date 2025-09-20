//
//  CustomAppManager.swift
//  PocketPrefs
//
//  Business logic for managing custom applications
//

import Foundation
import AppKit
import os.log

@MainActor
class CustomAppManager: ObservableObject {
    @Published var customApps: [AppConfig] = []
    @Published var selectedApp: AppConfig?
    @Published var selectedAppIds: Set<UUID> = []
    @Published var isAddingApp = false
    @Published var editingApp: AppConfig?
    
    private let logger = Logger(subsystem: "com.pocketprefs", category: "CustomAppManager")
    let userStore = UserConfigStore.shared  // Made internal for access
    private let fileOps = FileOperationService.shared
    
    init() {
        loadCustomApps()
    }
    
    func loadCustomApps() {
        customApps = userStore.customApps
        // 重置选中状态
        selectedApp = nil
        selectedAppIds.removeAll()
    }
    
    // Create a new app configuration
    func createNewApp(name: String, bundleId: String) -> AppConfig {
        return AppConfig(
            name: name,
            bundleId: bundleId,
            configPaths: [],
            isSelected: false,
            isInstalled: true,
            category: .custom,
            isUserAdded: true
        )
    }
    
    // Add a new custom app
    func addApp(_ app: AppConfig) {
        guard !userStore.bundleIdExists(app.bundleId) else {
            logger.warning("App with bundle ID \(app.bundleId) already exists")
            return
        }
        
        userStore.addApp(app)
        loadCustomApps()  // 重新加载以同步状态
        selectedApp = customApps.last  // 选中新添加的应用
    }
    
    // Update an existing app
    func updateApp(_ app: AppConfig) {
        userStore.updateApp(app)
        loadCustomApps()
        // 保持当前选中
        if let updated = customApps.first(where: { $0.id == app.id }) {
            selectedApp = updated
        }
    }
    
    // Remove selected apps
    func removeSelectedApps() {
        userStore.removeApps(selectedAppIds)
        selectedAppIds.removeAll()
        selectedApp = nil
        loadCustomApps()
    }
    
    // Add path to selected app
    func addPath(to app: AppConfig, path: String) {
        var updatedApp = app
        if !updatedApp.configPaths.contains(path) {
            updatedApp.configPaths.append(path)
            updateApp(updatedApp)
        }
    }
    
    // Remove path from app
    func removePath(from app: AppConfig, at index: Int) {
        guard index < app.configPaths.count else { return }
        
        var updatedApp = app
        updatedApp.configPaths.remove(at: index)
        updateApp(updatedApp)
    }
    
    // Edit path in app
    func editPath(in app: AppConfig, at index: Int, newPath: String) {
        guard index < app.configPaths.count else { return }
        
        var updatedApp = app
        updatedApp.configPaths[index] = newPath
        updateApp(updatedApp)
    }
    
    // Toggle app selection
    func toggleSelection(for appId: UUID) {
        if selectedAppIds.contains(appId) {
            selectedAppIds.remove(appId)
        } else {
            selectedAppIds.insert(appId)
        }
    }
    
    // Select all apps
    func selectAll() {
        selectedAppIds = Set(customApps.map { $0.id })
    }
    
    // Deselect all apps
    func deselectAll() {
        selectedAppIds.removeAll()
    }
    
    // Validate bundle ID format
    func isValidBundleId(_ bundleId: String) -> Bool {
        // 支持更灵活的格式，包括单词如 "git", "ssh" 等
        if bundleId.isEmpty { return false }
        
        // 简单的验证：字母开头，允许字母、数字、点、横线
        let pattern = "^[a-zA-Z][a-zA-Z0-9.-]*$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: bundleId.utf16.count)
        return regex?.firstMatch(in: bundleId, range: range) != nil
    }
    
    // Check if path exists
    func pathExists(_ path: String) -> Bool {
        let expandedPath = NSString(string: path).expandingTildeInPath
        return FileManager.default.fileExists(atPath: expandedPath)
    }
    
    // Get path type (file or directory)
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
}
