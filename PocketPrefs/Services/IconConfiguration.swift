//
//  IconConfiguration.swift
//  PocketPrefs
//
//  Icon configuration and terminal app definitions
//

import AppKit

/// Terminal application icon configuration
struct TerminalIconConfig {
    let letter: String
    let backgroundColor: NSColor
    let textColor: NSColor

    static let defaultBackground = NSColor.darkGray
    static let defaultTextColor = NSColor.systemGreen
}

/// Icon size and padding constants
enum IconConstants {
    static let standardSize = NSSize(width: 32, height: 32)
    static let terminalPadding: CGFloat = 3.5
    static let terminalCornerRadius: CGFloat = 5
    static let terminalFontSize: CGFloat = 14
}

/// Terminal app icon mappings
enum TerminalApps {
    static let iconMappings: [String: TerminalIconConfig] = [
        "oh-my-zsh": TerminalIconConfig(
            letter: "Z",
            backgroundColor: TerminalIconConfig.defaultBackground,
            textColor: TerminalIconConfig.defaultTextColor
        ),
        "git": TerminalIconConfig(
            letter: "G",
            backgroundColor: TerminalIconConfig.defaultBackground,
            textColor: TerminalIconConfig.defaultTextColor
        ),
        "ssh": TerminalIconConfig(
            letter: "S",
            backgroundColor: TerminalIconConfig.defaultBackground,
            textColor: TerminalIconConfig.defaultTextColor
        ),
        "homebrew": TerminalIconConfig(
            letter: "H",
            backgroundColor: TerminalIconConfig.defaultBackground,
            textColor: TerminalIconConfig.defaultTextColor
        ),
        // Future terminal tools can be added here
        "vim": TerminalIconConfig(
            letter: "V",
            backgroundColor: TerminalIconConfig.defaultBackground,
            textColor: TerminalIconConfig.defaultTextColor
        ),
        "tmux": TerminalIconConfig(
            letter: "T",
            backgroundColor: TerminalIconConfig.defaultBackground,
            textColor: TerminalIconConfig.defaultTextColor
        ),
        "docker": TerminalIconConfig(
            letter: "D",
            backgroundColor: NSColor(red: 0.13, green: 0.59, blue: 0.95, alpha: 1.0),
            textColor: NSColor.white
        ),
        "python": TerminalIconConfig(
            letter: "P",
            backgroundColor: NSColor(red: 0.22, green: 0.44, blue: 0.64, alpha: 1.0),
            textColor: NSColor(red: 1.0, green: 0.82, blue: 0.32, alpha: 1.0)
        ),
        "node": TerminalIconConfig(
            letter: "N",
            backgroundColor: NSColor(red: 0.16, green: 0.43, blue: 0.16, alpha: 1.0),
            textColor: NSColor.white
        ),
        "ruby": TerminalIconConfig(
            letter: "R",
            backgroundColor: NSColor(red: 0.61, green: 0.08, blue: 0.08, alpha: 1.0),
            textColor: NSColor.white
        )
    ]

    /// Get icon configuration for a bundle ID
    static func configuration(for bundleId: String) -> TerminalIconConfig? {
        return iconMappings[bundleId]
    }
}
