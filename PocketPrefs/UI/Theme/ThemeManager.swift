//
//  ThemeManager.swift
//  PocketPrefs
//
//  Enhanced theme management with glass effect support and structured concurrency
//

import SwiftUI

// MARK: - Enhanced Theme Manager

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

    /// Set theme with animation
    func setTheme(_ theme: Theme) {
        withAnimation(DesignConstants.Animation.smooth) {
            currentTheme = theme
            storedTheme = theme.rawValue
        }
    }
}

// MARK: - Enhanced Theme Definition

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

    /// Glass effect configuration for each theme
    var glassConfiguration: GlassConfiguration {
        switch self {
        case .system:
            return GlassConfiguration.adaptive
        case .light:
            return GlassConfiguration.light
        case .dark:
            return GlassConfiguration.dark
        }
    }
}

// MARK: - Glass Configuration

struct GlassConfiguration {
    let backgroundOpacity: Double
    let materialIntensity: Double
    let tintOpacity: Double

    static let adaptive = GlassConfiguration(
        backgroundOpacity: 0.72,
        materialIntensity: 0.85,
        tintOpacity: 0.08,
    )

    static let light = GlassConfiguration(
        backgroundOpacity: 0.72,
        materialIntensity: 0.85,
        tintOpacity: 0.08,
    )

    static let dark = GlassConfiguration(
        backgroundOpacity: 0.72,
        materialIntensity: 0.85,
        tintOpacity: 0.08,
    )
}

// MARK: - Enhanced Design Constants

enum DesignConstants {
    // Layout with glass effect considerations
    enum Layout {
        static let sidebarWidth: CGFloat = 70

        static let listWidth: CGFloat = 270
        static let minWindowWidth: CGFloat = 820
        static let minWindowHeight: CGFloat = 590

        static let cornerRadius: CGFloat = 12
        static let smallCornerRadius: CGFloat = 8

        static let spacing: CGFloat = 16
        static let smallSpacing: CGFloat = 8
        static let itemPadding: CGFloat = 12

        // Glass effect specific spacing
        static let glassSpacing: CGFloat = 13
        static let titleBarHeight: CGFloat = 28
        static let contentAreaBorderWidth: CGFloat = 1.0
    }

    // Enhanced typography with glass effect readability
    enum Typography {
        static let largeTitle: Font = .system(size: 26, weight: .bold, design: .rounded)
        static let title: Font = .system(size: 18, weight: .semibold, design: .rounded)
        static let headline: Font = .system(size: 12, weight: .semibold, design: .rounded)
        static let body: Font = .system(size: 12, weight: .medium)
        static let caption: Font = .system(size: 11, weight: .medium)
        static let tiny: Font = .system(size: 10, weight: .medium)
    }

    // Enhanced animations for glass effects
    enum Animation {
        static let standard = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.86)
        static let quick = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.9)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let glass = SwiftUI.Animation.easeInOut(duration: 0.25)
    }
}

// MARK: - Enhanced Visual Effects

struct EnhancedGlassEffect: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let intensity: Double

    init(intensity: Double = 1.0) {
        self.intensity = intensity
    }

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base glass material
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.85 * intensity)

                    // Enhanced glass overlay
                    AdaptiveColor.glassOverlay.color(for: colorScheme)
                        .opacity(0.5 * intensity)
                },
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignConstants.Layout.cornerRadius)
                    .stroke(
                        Color.App.lightSeparator.color(for: colorScheme).opacity(0.5 * intensity),
                        lineWidth: 0.5,
                    ),
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.Layout.cornerRadius))
    }
}

struct EnhancedCardEffect: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let isSelected: Bool
    let glassIntensity: Double

    init(isSelected: Bool = false, glassIntensity: Double = 0.8) {
        self.isSelected = isSelected
        self.glassIntensity = glassIntensity
    }

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base selection background
                    RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                        .fill(
                            isSelected
                                ? Color.App.accent.color(for: colorScheme).opacity(0.1)
                                : Color.clear,
                        )

                    // Glass effect background
                    RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                        .fill(.ultraThinMaterial)
                        .opacity(0.6 * glassIntensity)

                    // Hover background
                    RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                        .fill(Color.App.hoverBackground.color(for: colorScheme))
                },
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                    .stroke(
                        isSelected
                            ? Color.App.accent.color(for: colorScheme).opacity(0.3)
                            : Color.clear,
                        lineWidth: 1,
                    ),
            )
    }
}

// MARK: - Legacy Card Effect (for compatibility)

struct CardEffect: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                    .fill(isSelected ? (Color.App.accent.color(for: colorScheme)).opacity(0.1) : Color.clear),
            )
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                    .fill(Color.App.hoverBackground.color(for: colorScheme)),
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                    .stroke(
                        isSelected
                            ? (Color.App.accent.color(for: colorScheme)).opacity(0.3)
                            : Color.clear,
                        lineWidth: 1,
                    ),
            )
    }
}

// MARK: - Enhanced View Extensions

extension View {
    func enhancedGlassEffect(intensity: Double = 1.0) -> some View {
        modifier(EnhancedGlassEffect(intensity: intensity))
    }

    func enhancedCardEffect(isSelected: Bool = false, glassIntensity: Double = 0.8) -> some View {
        modifier(EnhancedCardEffect(isSelected: isSelected, glassIntensity: glassIntensity))
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
            .background(
                ZStack {
                    // Base section background
                    Color.App.tertiaryBackground.color(for: colorScheme).opacity(0.2)

                    // Subtle glass overlay
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                },
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius))
    }
}
