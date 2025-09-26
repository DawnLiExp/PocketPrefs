//
//  IconService.swift
//  PocketPrefs
//
//  Icon loading and caching service
//

import AppKit
import os.log

@MainActor
final class IconService {
    static let shared = IconService()
    private let logger = Logger(subsystem: "com.pocketprefs", category: "IconService")
    private let iconCache = NSCache<NSString, NSImage>()
    
    private init() {
        iconCache.countLimit = 100
    }
    
    // Get icon with caching
    func getIcon(for bundleId: String, category: AppCategory = .system) -> NSImage {
        if let cached = iconCache.object(forKey: bundleId as NSString) {
            return cached
        }
        
        let icon = fetchIcon(for: bundleId, category: category)
        iconCache.setObject(icon, forKey: bundleId as NSString)
        return icon
    }
    
    private func fetchIcon(for bundleId: String, category: AppCategory) -> NSImage {
        // Handle special cases for terminal tools using configuration
        if let config = TerminalApps.configuration(for: bundleId) {
            return createTerminalIcon(with: config)
        }
        
        // Try to get app icon
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            return resizedIcon(icon)
        }
        
        // Return category default icon
        logger.debug("Using default icon for \(bundleId)")
        return NSImage(systemSymbolName: category.icon, accessibilityDescription: nil) ?? NSImage()
    }
    
    private func createTerminalIcon(with config: TerminalIconConfig) -> NSImage {
        let size = IconConstants.standardSize
        return NSImage(size: size, flipped: false) { rect in
            // Add padding to match system app icons visual size
            let iconRect = rect.insetBy(dx: IconConstants.terminalPadding, dy: IconConstants.terminalPadding)
            
            // Background with adjusted corner radius
            config.backgroundColor.setFill()
            let path = NSBezierPath(roundedRect: iconRect, xRadius: IconConstants.terminalCornerRadius, yRadius: IconConstants.terminalCornerRadius)
            path.fill()
            
            // Terminal prompt design
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            // Adjusted font size for smaller icon area
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: IconConstants.terminalFontSize, weight: .bold),
                .foregroundColor: config.textColor,
                .paragraphStyle: paragraphStyle
            ]
            
            let text = ">_\(config.letter)"
            let textSize = text.size(withAttributes: attributes)
            let textRect = NSRect(
                x: iconRect.origin.x + (iconRect.width - textSize.width) / 2,
                y: iconRect.origin.y + (iconRect.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
            return true
        }
    }
    
    private func resizedIcon(_ icon: NSImage) -> NSImage {
        let size = IconConstants.standardSize
        let resized = NSImage(size: size)
        resized.lockFocus()
        icon.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: icon.size),
            operation: .sourceOver,
            fraction: 1.0
        )
        resized.unlockFocus()
        return resized
    }
}
