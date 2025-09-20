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
    case productivity = "Productivity"
    case system = "System"
    case terminal = "Terminal"
    case design = "Design"
    case custom = "Custom" // For user-added apps in future
    
    var icon: String {
        switch self {
        case .development: return "hammer.fill"
        case .productivity: return "briefcase.fill"
        case .system: return "gear"
        case .terminal: return "terminal.fill"
        case .design: return "paintbrush.fill"
        case .custom: return "plus.circle.fill"
        }
    }
}

// MARK: - App Configuration

struct AppConfig: Identifiable, Codable, Sendable, Equatable {
    var id = UUID()
    let name: String
    let bundleId: String
    var configPaths: [String]
    var isSelected: Bool = false
    var isInstalled: Bool = true
    var category: AppCategory = .development
    var isUserAdded: Bool = false // For future settings page
    
    enum CodingKeys: String, CodingKey {
        case name, bundleId, configPaths, category, isUserAdded
    }
    
    static func == (lhs: AppConfig, rhs: AppConfig) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Preset Configurations

extension AppConfig {
    static let presetConfigs: [AppConfig] = [
        // Development Tools
        AppConfig(
            name: "Visual Studio Code",
            bundleId: "com.microsoft.VSCode",
            configPaths: [
                "~/Library/Application Support/Code",
                "~/.vscode"
            ],
            category: .development
        ),
        
        AppConfig(
            name: "Xcode",
            bundleId: "com.apple.dt.Xcode",
            configPaths: [
                "~/Library/Developer/Xcode/UserData",
                "~/Library/Preferences/com.apple.dt.Xcode.plist"
            ],
            category: .development
        ),
        
        AppConfig(
            name: "Kaleidoscope",
            bundleId: "com.blackpixel.kaleidoscope",
            configPaths: [
                "~/Library/Application Support/Kaleidoscope",
                "~/Library/Preferences/com.blackpixel.kaleidoscope.plist"
            ],
            category: .development
        ),
        
        // Terminal Tools
        AppConfig(
            name: "iTerm2",
            bundleId: "com.googlecode.iterm2",
            configPaths: [
                "~/Library/Preferences/com.googlecode.iterm2.plist",
                "~/Library/Application Support/iTerm2"
            ],
            category: .terminal
        ),
        
        AppConfig(
            name: "Oh My Zsh",
            bundleId: "oh-my-zsh",
            configPaths: [
                "~/.zshrc",
                "~/.oh-my-zsh/custom"
            ],
            category: .terminal
        ),
        
        AppConfig(
            name: "Git",
            bundleId: "git",
            configPaths: [
                "~/.gitconfig",
                "~/.gitignore_global"
            ],
            category: .terminal
        ),
        
        AppConfig(
            name: "SSH",
            bundleId: "ssh",
            configPaths: ["~/.ssh/config"],
            category: .terminal
        ),
        
        AppConfig(
            name: "Homebrew",
            bundleId: "homebrew",
            configPaths: [
                "~/.Brewfile",
                "/usr/local/etc"
            ],
            category: .terminal
        ),
        
        // Productivity
        AppConfig(
            name: "Transmit",
            bundleId: "com.panic.Transmit",
            configPaths: [
                "~/Library/Application Support/Transmit",
                "~/Library/Preferences/com.panic.Transmit.plist"
            ],
            category: .productivity
        ),
        
        // Design
        AppConfig(
            name: "Pixelmator Pro",
            bundleId: "com.pixelmatorteam.pixelmator.x",
            configPaths: [
                "~/Library/Application Support/Pixelmator Pro",
                "~/Library/Preferences/com.pixelmatorteam.pixelmator.x.plist"
            ],
            category: .design
        )
    ]
}
