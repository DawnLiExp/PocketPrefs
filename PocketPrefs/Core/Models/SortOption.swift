//
//  SortOption.swift
//  PocketPrefs
//
//  Sort options for app lists
//

import Foundation

// MARK: - Sort Option

enum SortOption: String, CaseIterable, Sendable {
    case nameAscending
    case nameDescending
    case dateAdded

    var displayName: String {
        switch self {
        case .nameAscending:
            return NSLocalizedString("Sort_Name_Ascending", comment: "")
        case .nameDescending:
            return NSLocalizedString("Sort_Name_Descending", comment: "")
        case .dateAdded:
            return NSLocalizedString("Sort_Date_Added", comment: "")
        }
    }
}

// MARK: - Sorting Helpers

extension SortOption {
    /// Apply sorting to app configurations
    func apply(to apps: [AppConfig]) -> [AppConfig] {
        switch self {
        case .nameAscending:
            return apps.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

        case .nameDescending:
            return apps.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending
            }

        case .dateAdded:
            // Preset apps first (maintain order), custom apps last (reversed)
            let preset = apps.filter { !$0.isUserAdded }
            let custom = apps.filter(\.isUserAdded).reversed()
            return preset + Array(custom)
        }
    }

    /// Apply sorting to backup app info
    func apply(to apps: [BackupAppInfo]) -> [BackupAppInfo] {
        switch self {
        case .nameAscending:
            return apps.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

        case .nameDescending:
            return apps.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending
            }

        case .dateAdded:
            // For backup apps, maintain original order (already sorted by backup creation)
            return apps
        }
    }
}
