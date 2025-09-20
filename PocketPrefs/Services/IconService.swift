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
        // Handle special cases for terminal tools
        switch bundleId {
        case "oh-my-zsh": return createTerminalIcon(with: "Z")
        case "git": return createTerminalIcon(with: "G")
        case "ssh": return createTerminalIcon(with: "S")
        case "homebrew": return createTerminalIcon(with: "H")
        default: break
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
    
    private func createTerminalIcon(with letter: String) -> NSImage {
        let size = NSSize(width: 32, height: 32)
        return NSImage(size: size, flipped: false) { rect in
            NSColor.darkGray.setFill()
            let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
            path.fill()
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .bold),
                .foregroundColor: NSColor.systemGreen,
                .paragraphStyle: paragraphStyle
            ]
            
            let text = ">_\(letter)"
            let textSize = text.size(withAttributes: attributes)
            let textRect = NSRect(
                x: (rect.width - textSize.width) / 2,
                y: (rect.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
            return true
        }
    }
    
    private func resizedIcon(_ icon: NSImage, size: NSSize = NSSize(width: 32, height: 32)) -> NSImage {
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
