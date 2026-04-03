//
//  AppInfoReader.swift
//  PocketPrefs
//
//  Service for reading application bundle information - used in Settings
//

import Foundation
import os.log

struct AppInfo {
    let name: String
    let bundleId: String
}

enum AppInfoError: LocalizedError {
    case invalidAppBundle
    case infoPlistNotFound
    case missingRequiredKeys
    case readFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidAppBundle:
            return String(localized: "AppInfo_Error_Invalid_Bundle", defaultValue: "Invalid application bundle")
        case .infoPlistNotFound:
            return String(localized: "AppInfo_Error_Plist_Not_Found", defaultValue: "Info.plist not found in application")
        case .missingRequiredKeys:
            return String(localized: "AppInfo_Error_Missing_Keys", defaultValue: "Required information missing in application")
        case .readFailed(let error):
            return String(localized: "AppInfo_Error_Read_Failed", defaultValue: "Failed to read application info: \(error.localizedDescription)")
        }
    }
}

actor AppInfoReader {
    private let logger = Logger(subsystem: "com.me2.PocketPrefs", category: "AppInfoReader")
    
    func readAppInfo(from appURL: URL) async throws -> AppInfo {
        logger.info("Reading app info from: \(appURL.path)")
        
        guard appURL.pathExtension == "app" else {
            logger.error("Invalid app bundle: \(appURL.path)")
            throw AppInfoError.invalidAppBundle
        }
        
        let infoPlistURL = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Info.plist")
        
        guard FileManager.default.fileExists(atPath: infoPlistURL.path) else {
            logger.error("Info.plist not found at: \(infoPlistURL.path)")
            throw AppInfoError.infoPlistNotFound
        }
        
        do {
            let data = try Data(contentsOf: infoPlistURL)
            let plist = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil,
            )
            
            guard let dict = plist as? [String: Any] else {
                logger.error("Invalid plist format")
                throw AppInfoError.missingRequiredKeys
            }
            
            // Extract Bundle ID
            guard let bundleId = dict["CFBundleIdentifier"] as? String else {
                logger.error("CFBundleIdentifier not found in Info.plist")
                throw AppInfoError.missingRequiredKeys
            }
            
            // Extract App Name (prefer CFBundleDisplayName, fallback to CFBundleName)
            let appName = (dict["CFBundleDisplayName"] as? String) ??
                (dict["CFBundleName"] as? String) ??
                appURL.deletingPathExtension().lastPathComponent
            
            logger.info("Successfully read app info: \(appName) (\(bundleId))")
            
            return AppInfo(name: appName, bundleId: bundleId)
            
        } catch {
            logger.error("Failed to read app info: \(error)")
            throw AppInfoError.readFailed(error)
        }
    }
}
