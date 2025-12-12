//
//  SystemVersionDetector.swift
//  PocketPrefs
//
//  System version detection utility for UI adaptation
//

import Foundation

enum SystemVersionDetector {
    /// Current macOS version
    static let current = ProcessInfo.processInfo.operatingSystemVersion
    
    /// Check if running on macOS 26.0 or later (Tahoe)
    static var isMacOS26OrLater: Bool {
        if #available(macOS 26.0, *) {
            return true
        }
        return false
    }
    
    /// Check if running on macOS 15.0 or later (Sequoia)
    static var isMacOS15OrLater: Bool {
        if #available(macOS 15.0, *) {
            return true
        }
        return false
    }
    
    /// Get appropriate corner radius for current OS
    static var cornerRadius: CGFloat {
        isMacOS26OrLater ? 14 : 12
    }
    
    /// Get appropriate small corner radius for current OS
    static var smallCornerRadius: CGFloat {
        isMacOS26OrLater ? 10 : 8
    }
    
    /// Get appropriate sidebar gap for current OS (spacing between sidebar and content)
    static var sidebarGap: CGFloat {
        isMacOS26OrLater ? 8 : 0
    }
    
    /// Get appropriate list width for current OS
    static var listWidth: CGFloat {
        isMacOS26OrLater ? 278 : 270
    }
}
