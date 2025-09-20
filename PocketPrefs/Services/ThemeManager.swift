//
//  ThemeManager.swift
//  PocketPrefs
//
//  Theme management and design constants
//

import SwiftUI

// MARK: - Theme Manager

@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: Theme = .system
    @AppStorage("preferredTheme") private var storedTheme: String = "system"

    private init() {
        loadTheme()
    }

    private func loadTheme() {
        currentTheme = Theme(rawValue: storedTheme) ?? .system
    }

    func setTheme(_ theme: Theme) {
        currentTheme = theme
        storedTheme = theme.rawValue
    }
}

// MARK: - Theme Definition

enum Theme: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return NSLocalizedString("Theme_Follow_System", comment: "")
        case .light: return NSLocalizedString("Theme_Light", comment: "")
        case .dark: return NSLocalizedString("Theme_Dark", comment: "")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Design Constants

enum DesignConstants {
    // Layout
    enum Layout {
        static let sidebarWidth: CGFloat = 75
        static let listWidth: CGFloat = 280
        static let minWindowWidth: CGFloat = 820
        static let minWindowHeight: CGFloat = 600

        static let cornerRadius: CGFloat = 10
        static let smallCornerRadius: CGFloat = 6

        static let spacing: CGFloat = 16
        static let smallSpacing: CGFloat = 8
        static let itemPadding: CGFloat = 12
    }

    // Typography
    enum Typography {
        static let largeTitle: Font = .system(size: 28, weight: .bold, design: .rounded)
        static let title: Font = .system(size: 20, weight: .semibold, design: .rounded)
        static let headline: Font = .system(size: 14, weight: .semibold, design: .rounded)
        static let body: Font = .system(size: 13)
        static let caption: Font = .system(size: 11)
        static let tiny: Font = .system(size: 10)
    }

    // Animation
    enum Animation {
        static let standard = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.86)
        static let quick = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.9)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.3)
    }
}

// MARK: - Visual Effects

struct GlassEffect: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(
                AdaptiveColor.glassOverlay.color(for: colorScheme)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignConstants.Layout.cornerRadius)
                    .stroke(
                        colorScheme == .dark
                            ? Color.App.primary.color(for: colorScheme).opacity(0.1)
                            : Color.App.primary.color(for: colorScheme).opacity(0.05),
                        lineWidth: 0.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.Layout.cornerRadius))
    }
}

struct CardEffect: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                    .fill(isSelected ? Color.App.accent.color(for: colorScheme).opacity(0.1) : Color.clear)
            )
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                    .fill(Color.App.tertiaryBackground.color(for: colorScheme).opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                    .stroke(
                        isSelected
                            ? Color.App.accent.color(for: colorScheme).opacity(0.3)
                            : Color.clear,
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - View Extensions

extension View {
    func glassEffect() -> some View {
        modifier(GlassEffect())
    }

    func cardEffect(isSelected: Bool = false) -> some View {
        modifier(CardEffect(isSelected: isSelected))
    }

    func sectionBackground() -> some View {
        modifier(SectionBackgroundModifier())
    }
}

private struct SectionBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(Color.App.tertiaryBackground.color(for: colorScheme).opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.Layout.cornerRadius))
    }
}
