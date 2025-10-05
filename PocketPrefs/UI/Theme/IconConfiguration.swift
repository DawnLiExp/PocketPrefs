//
//  IconConfiguration.swift
//  PocketPrefs
//
//  Icon configuration and terminal app definitions
//

import AppKit

// MARK: - Terminal Icon Configuration

struct TerminalIconConfig: Sendable {
    let letter: String
    let backgroundColor: NSColor
    let textColor: NSColor

    static let defaultBackground = NSColor.darkGray
    static let defaultTextColor = NSColor.systemGreen
}

// MARK: - Icon Constants

enum IconConstants {
    static let standardSize = NSSize(width: 32, height: 32)
    static let terminalPadding: CGFloat = 3.5
    static let terminalCornerRadius: CGFloat = 5
    static let terminalFontSize: CGFloat = 14
}

// MARK: - Terminal App Registry

enum TerminalApps {
    private static let registry: [String: TerminalIconConfig] = [
        "oh-my-zsh": .init(
            letter: "Z",
            backgroundColor: .darkGray,
            textColor: .systemGreen,
        ),
        "git": .init(
            letter: "G",
            backgroundColor: .darkGray,
            textColor: .systemGreen,
        ),
        "ssh": .init(
            letter: "S",
            backgroundColor: .darkGray,
            textColor: .systemGreen,
        ),
        "homebrew": .init(
            letter: "H",
            backgroundColor: .darkGray,
            textColor: .systemGreen,
        ),
        "vim": .init(
            letter: "V",
            backgroundColor: .darkGray,
            textColor: .systemGreen,
        ),
        "tmux": .init(
            letter: "T",
            backgroundColor: .darkGray,
            textColor: .systemGreen,
        ),
        "docker": .init(
            letter: "D",
            backgroundColor: NSColor(red: 0.13, green: 0.59, blue: 0.95, alpha: 1.0),
            textColor: .white,
        ),
        "python": .init(
            letter: "P",
            backgroundColor: NSColor(red: 0.22, green: 0.44, blue: 0.64, alpha: 1.0),
            textColor: NSColor(red: 1.0, green: 0.82, blue: 0.32, alpha: 1.0),
        ),
        "node": .init(
            letter: "N",
            backgroundColor: NSColor(red: 0.16, green: 0.43, blue: 0.16, alpha: 1.0),
            textColor: .white,
        ),
        "ruby": .init(
            letter: "R",
            backgroundColor: NSColor(red: 0.61, green: 0.08, blue: 0.08, alpha: 1.0),
            textColor: .white,
        ),
    ]

    static func configuration(for bundleId: String) -> TerminalIconConfig? {
        registry[bundleId]
    }

    static func isTerminalApp(_ bundleId: String) -> Bool {
        registry[bundleId] != nil
    }
}
