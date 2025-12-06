//
//  AppConfig.swift
//  PocketPrefs
//
//  Application configuration model
//

import Foundation

// MARK: - App Category

enum AppCategory: String, Codable, CaseIterable, Sendable {
    case development = "Development"
    case media = "Media"
    case productivity = "Productivity"
    case reading = "Reading"
    case system = "System"
    case terminal = "Terminal"
    case utility = "Utility"
    case graphicsDesign = "Graphics & Design"
    case photography = "Photography"
    case reference = "Reference"
    case custom = "Custom"

    var icon: String {
        switch self {
        case .development:
            return "hammer"
        case .media:
            return "play.circle"
        case .productivity:
            return "checklist"
        case .system: return "gear"
        case .reading:
            return "book"
        case .terminal:
            return "terminal"
        case .utility:
            return "wrench"
        case .graphicsDesign:
            return "paintbrush"
        case .photography:
            return "camera"
        case .reference:
            return "doc.text.magnifyingglass"
        case .custom:
            return "person.crop.circle.fill.badge.plus"
        }
    }
}

// MARK: - App Configuration

struct AppConfig: Identifiable, Codable, Sendable, Equatable {
    var id = UUID()
    var name: String
    let bundleId: String
    var configPaths: [String]
    var isSelected: Bool = false
    var isInstalled: Bool = true
    var category: AppCategory = .development
    var isUserAdded: Bool = false
    var createdAt: Date = .init()

    enum CodingKeys: String, CodingKey {
        case name, bundleId, configPaths, category, isUserAdded, createdAt
    }

    static func == (lhs: AppConfig, rhs: AppConfig) -> Bool {
        lhs.id == rhs.id &&
            lhs.name == rhs.name &&
            lhs.bundleId == rhs.bundleId &&
            lhs.configPaths == rhs.configPaths &&
            lhs.category == rhs.category &&
            lhs.isUserAdded == rhs.isUserAdded
    }
}

// MARK: - Preset Configurations

extension AppConfig {
    static let presetConfigs: [AppConfig] = [
        AppConfig(
            name: "Git",
            bundleId: "git",
            configPaths: [
                "~/.gitconfig",
                "~/.gitignore_global"
            ],
            category: .terminal,
            createdAt: Date(timeIntervalSince1970: 0)
        ),

        AppConfig(
            name: "Oh My Zsh",
            bundleId: "oh-my-zsh",
            configPaths: [
                "~/.zshrc",
                "~/.oh-my-zsh/custom"
            ],
            category: .terminal,
            createdAt: Date(timeIntervalSince1970: 0)
        ),

        AppConfig(
            name: "SSH",
            bundleId: "ssh",
            configPaths: ["~/.ssh/config"],
            category: .terminal,
            createdAt: Date(timeIntervalSince1970: 0)
        ),

        AppConfig(
            name: "BetterTouchTool",
            bundleId: "com.hegenberg.BetterTouchTool",
            configPaths: [
                "~/Library/Preferences/com.hegenberg.bettertouchtool-setapp.plist",
                "~/Library/Application Support/BetterTouchTool/"
            ],
            category: .utility,
            createdAt: Date(timeIntervalSince1970: 0)
        ),

        AppConfig(
            name: "Calibre",
            bundleId: "net.kovidgoyal.calibre",
            configPaths: ["~/Library/Preferences/calibre"],
            category: .reading,
            createdAt: Date(timeIntervalSince1970: 0)
        ),

        AppConfig(
            name: "IINA",
            bundleId: "com.colliderli.iina",
            configPaths: [
                "~/Library/Application Support/com.colliderli.iina/plugins",
                "~/Library/Preferences/com.colliderli.iina.plist",
                "~/Library/Application Support/com.colliderli.iina/input_conf"
            ],
            category: .media,
            createdAt: Date(timeIntervalSince1970: 0)
        ),

        AppConfig(
            name: "Input Source Pro",
            bundleId: "com.runjuu.Input-Source-Pro",
            configPaths: [
                "~/Library/Application Support/Input Source Pro",
                "~/Library/Preferences/com.runjuu.Input-Source-Pro.plist"
            ],
            category: .utility,
            createdAt: Date(timeIntervalSince1970: 0)
        ),

        AppConfig(
            name: "Karabiner-Elements",
            bundleId: "org.pqrs.Karabiner-Elements.Settings",
            configPaths: [
                "~/.config/karabiner",
                "~/Library/Preferences/org.pqrs.Karabiner-Elements.Settings.plist"
            ],
            category: .utility,
            createdAt: Date(timeIntervalSince1970: 0)
        ),

        AppConfig(
            name: "Me2Comic",
            bundleId: "me2.comic.me2comic",
            configPaths: ["~/Library/Preferences/me2.comic.me2comic.plist"],
            category: .graphicsDesign,
            createdAt: Date(timeIntervalSince1970: 0)
        ),

        AppConfig(
            name: "PopClip",
            bundleId: "com.pilotmoon.popclip",
            configPaths: [
                "~/Library/Application Support/PopClip/Extensions",
                "~/Library/Preferences/com.pilotmoon.popclip.plist"
            ],
            category: .productivity,
            createdAt: Date(timeIntervalSince1970: 0)
        ),

        AppConfig(
            name: "reeder",
            bundleId: "com.reederapp.5.macOS",
            configPaths: [
                "~/Library/Containers/com.reederapp.5.macOS/Data/Library/Application Support/users.json",
                "~/Library/Containers/com.reederapp.5.macOS/Data/Library/Preferences/com.reederapp.5.macOS.plist"
            ],
            category: .reading,
            createdAt: Date(timeIntervalSince1970: 0)
        ),

        AppConfig(
            name: "squirrel",
            bundleId: "im.rime.inputmethod.Squirrel",
            configPaths: ["~/Library/Rime"],
            category: .utility,
            createdAt: Date(timeIntervalSince1970: 0)
        ),

        AppConfig(
            name: "Visual Studio Code",
            bundleId: "com.microsoft.VSCode",
            configPaths: [
                "~/Library/Application Support/Code/User/snippets",
                "~/Library/Application Support/Code/User/prompts",
                "~/Library/Application Support/Code/User/keybindings.json",
                "~/Library/Application Support/Code/User/settings.json",
                "~/.vscode/extensions"
            ],
            category: .development,
            createdAt: Date(timeIntervalSince1970: 0)
        ),

        AppConfig(
            name: "Warp",
            bundleId: "dev.warp.Warp-Stable",
            configPaths: [
                "~/.warp",
                "~/Library/Preferences/dev.warp.Warp-Stable.plist"
            ],
            category: .terminal,
            createdAt: Date(timeIntervalSince1970: 0)
        ),

        AppConfig(
            name: "Zed",
            bundleId: "dev.zed.Zed",
            configPaths: [
                "~/.config/zed/settings.json",
                "~/.config/zed/keymap.json"
            ],
            category: .development,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    ]
}
