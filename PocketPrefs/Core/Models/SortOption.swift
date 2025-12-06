//
//  SortOption.swift
//  PocketPrefs
//
//  Sort options for app lists
//

import Foundation

enum SortOption: String, CaseIterable, Sendable {
    case nameAscending = "name_asc"
    case nameDescending = "name_desc"
    case dateAddedDescending = "date_added_desc"
    
    var displayName: String {
        switch self {
        case .nameAscending:
            return NSLocalizedString("Sort_Name_Ascending", comment: "Name (A-Z)")
        case .nameDescending:
            return NSLocalizedString("Sort_Name_Descending", comment: "Name (Z-A)")
        case .dateAddedDescending:
            return NSLocalizedString("Sort_Date_Added", comment: "Latest Added")
        }
    }
    
    // MARK: - AppConfig Sorting
    
    func apply(to apps: [AppConfig]) -> [AppConfig] {
        switch self {
        case .nameAscending:
            return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
        case .nameDescending:
            return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
            
        case .dateAddedDescending:
            // User-added apps first (sorted by createdAt descending), then preset apps
            let userAdded = apps.filter(\.isUserAdded)
                .sorted { $0.createdAt > $1.createdAt }
            let presets = apps.filter { !$0.isUserAdded }
            return userAdded + presets
        }
    }
    
    // MARK: - BackupAppInfo Sorting
    
    func apply(to apps: [BackupAppInfo]) -> [BackupAppInfo] {
        switch self {
        case .nameAscending:
            return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
        case .nameDescending:
            return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
            
        case .dateAddedDescending:
            // BackupAppInfo doesn't support date sorting, return as-is
            return apps
        }
    }
}
