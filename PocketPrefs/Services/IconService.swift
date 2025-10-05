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
    
    private let eventContinuation: AsyncStream<String>.Continuation
    let events: AsyncStream<String>
    
    private init() {
        iconCache.countLimit = 100
        (events, eventContinuation) = AsyncStream<String>.makeStream()
    }
    
    // MARK: - Public Interface
    
    func getIcon(for bundleId: String, category: AppCategory = .system) -> NSImage {
        if let cached = iconCache.object(forKey: bundleId as NSString) {
            return cached
        }
        
        if TerminalApps.isTerminalApp(bundleId) {
            Task { await loadTerminalIcon(for: bundleId) }
            return createPlaceholderIcon()
        }
        
        let icon = fetchApplicationIcon(for: bundleId, category: category)
        cacheIcon(icon, for: bundleId)
        return icon
    }
    
    // MARK: - Icon Loading
    
    private func loadTerminalIcon(for bundleId: String) async {
        guard let config = TerminalApps.configuration(for: bundleId) else {
            logger.warning("No terminal config found for: \(bundleId)")
            return
        }
        
        let icon = Self.createTerminalIcon(with: config)
        cacheIcon(icon, for: bundleId)
        eventContinuation.yield(bundleId)
        
        logger.debug("Terminal icon loaded: \(bundleId)")
    }
    
    private func fetchApplicationIcon(for bundleId: String, category: AppCategory) -> NSImage {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let icon = loadIconFromWorkspace(at: appURL)
        {
            return icon
        }
        
        logger.debug("Using fallback icon for: \(bundleId)")
        return createFallbackIcon(for: category)
    }
    
    private func loadIconFromWorkspace(at url: URL) -> NSImage? {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        return resizeIcon(icon, to: IconConstants.standardSize)
    }
    
    // MARK: - Icon Creation
    
    private static func createTerminalIcon(with config: TerminalIconConfig) -> NSImage {
        NSImage(size: IconConstants.standardSize, flipped: false) { rect in
            let iconRect = rect.insetBy(
                dx: IconConstants.terminalPadding,
                dy: IconConstants.terminalPadding,
            )
            
            config.backgroundColor.setFill()
            NSBezierPath(
                roundedRect: iconRect,
                xRadius: IconConstants.terminalCornerRadius,
                yRadius: IconConstants.terminalCornerRadius,
            ).fill()
            
            drawTerminalText(config.letter, with: config.textColor, in: iconRect)
            return true
        }
    }
    
    private static func drawTerminalText(_ letter: String, with color: NSColor, in rect: NSRect) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(
                ofSize: IconConstants.terminalFontSize,
                weight: .bold,
            ),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
        ]
        
        let text = ">_\(letter)"
        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: rect.origin.x + (rect.width - textSize.width) / 2,
            y: rect.origin.y + (rect.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height,
        )
        
        text.draw(in: textRect, withAttributes: attributes)
    }
    
    private func createPlaceholderIcon() -> NSImage {
        NSImage(size: IconConstants.standardSize, flipped: false) { rect in
            NSColor.systemGray.withAlphaComponent(0.3).setFill()
            NSBezierPath(
                roundedRect: rect.insetBy(
                    dx: IconConstants.terminalPadding,
                    dy: IconConstants.terminalPadding,
                ),
                xRadius: IconConstants.terminalCornerRadius,
                yRadius: IconConstants.terminalCornerRadius,
            ).fill()
            return true
        }
    }
    
    private func createFallbackIcon(for category: AppCategory) -> NSImage {
        NSImage(
            systemSymbolName: category.icon,
            accessibilityDescription: nil,
        ) ?? NSImage()
    }
    
    // MARK: - Icon Processing
    
    private func resizeIcon(_ icon: NSImage, to size: NSSize) -> NSImage {
        let resized = NSImage(size: size)
        resized.lockFocus()
        icon.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: icon.size),
            operation: .sourceOver,
            fraction: 1.0,
        )
        resized.unlockFocus()
        return resized
    }
    
    // MARK: - Cache Management
    
    private func cacheIcon(_ icon: NSImage, for bundleId: String) {
        iconCache.setObject(icon, forKey: bundleId as NSString)
    }
}
