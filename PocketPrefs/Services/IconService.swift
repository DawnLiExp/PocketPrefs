//
//  IconService.swift
//  PocketPrefs
//
//  Icon loading and caching service with async terminal icon generation
//

import AppKit
import os.log

@MainActor
final class IconService {
    static let shared = IconService()
    private let logger = Logger(subsystem: "com.pocketprefs", category: "IconService")
    private let iconCache = NSCache<NSString, NSImage>()
    private let placeholderIcon: NSImage
    
    private init() {
        iconCache.countLimit = 100
        
        // Create placeholder icon
        placeholderIcon = NSImage(size: IconConstants.standardSize, flipped: false) { rect in
            NSColor.systemGray.withAlphaComponent(0.3).setFill()
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: IconConstants.terminalPadding, dy: IconConstants.terminalPadding),
                                    xRadius: IconConstants.terminalCornerRadius,
                                    yRadius: IconConstants.terminalCornerRadius)
            path.fill()
            return true
        }
    }
    
    func getIcon(for bundleId: String, category: AppCategory = .system) -> NSImage {
        if let cached = iconCache.object(forKey: bundleId as NSString) {
            return cached
        }
        
        // Handle terminal tools: return placeholder, load async
        if TerminalApps.configuration(for: bundleId) != nil {
            Task {
                await loadTerminalIconAsync(for: bundleId)
            }
            return placeholderIcon
        }
        
        // Standard app icons
        let icon = fetchIcon(for: bundleId, category: category)
        iconCache.setObject(icon, forKey: bundleId as NSString)
        return icon
    }
    
    private func loadTerminalIconAsync(for bundleId: String) async {
        guard let config = TerminalApps.configuration(for: bundleId) else { return }
        
        // Create icon in background
        let icon = await Task.detached(priority: .userInitiated) {
            await Self.createTerminalIcon(with: config)
        }.value
        
        // Cache on main thread
        iconCache.setObject(icon, forKey: bundleId as NSString)
    }
    
    private func fetchIcon(for bundleId: String, category: AppCategory) -> NSImage {
        // Try to get app icon
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            return resizedIcon(icon)
        }
        
        // Return category default icon
        logger.debug("Using default icon for \(bundleId)")
        return NSImage(systemSymbolName: category.icon, accessibilityDescription: nil) ?? NSImage()
    }
    
    private static func createTerminalIcon(with config: TerminalIconConfig) -> NSImage {
        let size = IconConstants.standardSize
        return NSImage(size: size, flipped: false) { rect in
            let iconRect = rect.insetBy(dx: IconConstants.terminalPadding, dy: IconConstants.terminalPadding)
            
            // Background
            config.backgroundColor.setFill()
            let path = NSBezierPath(roundedRect: iconRect, xRadius: IconConstants.terminalCornerRadius, yRadius: IconConstants.terminalCornerRadius)
            path.fill()
            
            // Terminal prompt design
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
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
