//
//  ColorExtensions.swift
//  PocketPrefs
//
//  Color utilities and adaptive color palette
//

import SwiftUI

extension Color {
    /// Initializes a Color from a hexadecimal string.
    /// - Parameters:
    ///   - hex: The hexadecimal string (e.g., "#RRGGBB", "#AARRGGBB", "RRGGBB", "AARRGGBB").
    ///   - opacity: The opacity of the color, defaults to 1.0.
    init(hex: String, opacity: Double = 1.0) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = opacity

        let length = hexSanitized.count

        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Adaptive Color

/// A structure to define colors that adapt to light and dark mode.
struct AdaptiveColor {
    let light: Color
    let dark: Color

    /// Returns the appropriate color based on the current color scheme.
    /// - Parameter scheme: The current `ColorScheme`.
    /// - Returns: The `Color` for the given scheme.
    func color(for scheme: ColorScheme) -> Color {
        scheme == .dark ? dark : light
    }
}

// MARK: - Color Palette

extension Color {
    enum App {
        // Primary Colors
        static let accent = AdaptiveColor(
            light: Color(hex: "748873"),
            dark: Color(hex: "8D99AE")
        )
        static let primary = AdaptiveColor(
            light: Color(hex: "1C1C1E"),
            dark: Color(hex: "FFFFFF")
        )
        static let secondary = AdaptiveColor(
            light: Color(hex: "3C3C43", opacity: 0.6),
            dark: Color(hex: "EBEBF5", opacity: 0.6)
        )

        // Semantic Colors
        static let success = AdaptiveColor(
            light: Color(hex: "34C759"),
            dark: Color(hex: "32D74B")
        )
        static let warning = AdaptiveColor(
            light: Color(hex: "FF9500"),
            dark: Color(hex: "FF9F0A")
        )
        static let error = AdaptiveColor(
            light: Color(hex: "FF3B30"),
            dark: Color(hex: "FF453A")
        )
        static let info = AdaptiveColor(
            light: Color(hex: "007AFF"),
            dark: Color(hex: "0A84FF")
        )

        // New unified background system
        static let unifiedBackground = AdaptiveColor(
            light: Color(hex: "F5F2ED"),
            dark: Color(hex: "44444E")
        )

        // Content area backgrounds (floating windows)
        static let contentAreaBackground = AdaptiveColor(
            light: Color(hex: "fdfbfa"),
            dark: Color(hex: "1C1C1E")
        )

        // Legacy background colors (kept for compatibility)
        static let background = AdaptiveColor(
            light: Color(hex: "F5F5F7"),
            dark: Color(hex: "0D0D0D")
        )
        static let secondaryBackground = AdaptiveColor(
            light: Color(hex: "FFFFFF"),
            dark: Color(hex: "1C1C1E")
        )
        static let tertiaryBackground = AdaptiveColor(
            light: Color(hex: "F5F2ED"),
            dark: Color(hex: "2C2C2E")
        )

        // Interactive Elements
        static let controlBackground = AdaptiveColor(
            light: Color(hex: "FFFFFF"),
            dark: Color(hex: "1C1C1E")
        )
        static let selectedControlBackground = AdaptiveColor(
            light: Color(hex: "7A9A7A"),
            dark: Color(hex: "0A84FF")
        )
        static let hoverBackground = AdaptiveColor(
            light: Color(hex: "7A9A7A", opacity: 0.08),
            dark: Color(hex: "44444E", opacity: 0.08)
        )

        // Text Colors
        static let primaryText = AdaptiveColor(
            light: Color(hex: "1C1C1E"),
            dark: Color(hex: "FFFFFF")
        )
        static let secondaryText = AdaptiveColor(
            light: Color(hex: "3C3C43", opacity: 0.6),
            dark: Color(hex: "EBEBF5", opacity: 0.6)
        )
        static let tertiaryText = AdaptiveColor(
            light: Color(hex: "3C3C43", opacity: 0.3),
            dark: Color(hex: "EBEBF5", opacity: 0.3)
        )
        static let disabledText = AdaptiveColor(
            light: Color(hex: "3C3C43", opacity: 0.3),
            dark: Color(hex: "EBEBF5", opacity: 0.3)
        )

        // Separator (subtle, for minimal visibility)
        static let separator = AdaptiveColor(
            light: Color(hex: "C6C6C8"),
            dark: Color(hex: "38383A")
        )
        static let lightSeparator = AdaptiveColor(
            light: Color(hex: "748873", opacity: 0.8),
            dark: Color(hex: "8D99AE", opacity: 0.8)
        )

        // Status Colors
        static let installed = AdaptiveColor(
            light: Color(hex: "748873", opacity: 0.8),
            dark: Color(hex: "748873", opacity: 0.8)
        )
        static let notInstalled = AdaptiveColor(
            light: Color(hex: "FF9500", opacity: 0.8),
            dark: Color(hex: "FF9F0A", opacity: 0.8)
        )
        static let processing = AdaptiveColor(
            light: Color(hex: "007AFF", opacity: 0.8),
            dark: Color(hex: "0A84FF", opacity: 0.8)
        )

        // Progress Colors
        static let progressTrack = AdaptiveColor(
            light: Color(hex: "8E8E93", opacity: 0.2),
            dark: Color(hex: "8E8E93", opacity: 0.2)
        )
        static let progressFill = AdaptiveColor(
            light: Color(hex: "007AFF"),
            dark: Color(hex: "0A84FF")
        )
    }
}

// MARK: - Gradient Definitions

extension LinearGradient {
    /// A linear gradient using the app's accent colors, adapting to the given color scheme.
    /// - Parameter scheme: The current `ColorScheme`.
    static func appAccent(for scheme: ColorScheme) -> LinearGradient {
        let accentColor = Color.App.accent.color(for: scheme)
        let endColor = scheme == .dark ? Color(hex: "636366") : Color(hex: "C7C7CC")

        return LinearGradient(
            gradient: Gradient(colors: [accentColor, endColor]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - View Extensions for Backgrounds

extension View {
    /// Applies the new unified background (main + sidebar) with glass effect
    func unifiedBackground() -> some View {
        modifier(UnifiedBackgroundModifier())
    }

    /// Applies content area background (floating window effect)
    func contentAreaBackground() -> some View {
        modifier(ContentAreaBackgroundModifier())
    }

    /// Applies a sidebar background style.
    func sidebarBackground() -> some View {
        modifier(SidebarBackgroundModifier())
    }

    /// Applies a content background style.
    func contentBackground() -> some View {
        modifier(ContentBackgroundModifier())
    }
}

private struct UnifiedBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base color with transparency for glass effect
                    (Color.App.unifiedBackground.color(for: colorScheme))
                        .opacity(0.80)

                    // Material layer for blur
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.75)
                }
            )
    }
}

private struct ContentAreaBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(Color.App.contentAreaBackground.color(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.Layout.cornerRadius))
            .shadow(
                color: colorScheme == .dark
                    ? Color.black.opacity(0.3)
                    : Color.black.opacity(0.08),
                radius: 8,
                x: 0,
                y: 2
            )
    }
}

private struct SidebarBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base color with transparency
                    (Color.App.unifiedBackground.color(for: colorScheme))
                        .opacity(0.30)

                    // Material layer
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.75)
                }
            )
    }
}

private struct ContentBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(Color.App.contentAreaBackground.color(for: colorScheme))
    }
}

// MARK: - Shadow Definitions

extension View {
    /// Applies a soft shadow effect.
    func softShadow() -> some View {
        modifier(SoftShadowModifier())
    }

    /// Applies an elevation shadow effect based on a level.
    /// - Parameter level: The elevation level.
    func elevationShadow(_ level: Int = 1) -> some View {
        modifier(ElevationShadowModifier(level: level))
    }
}

private struct SoftShadowModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .shadow(
                color: (Color.App.primary.color(for: colorScheme)).opacity(0.1),
                radius: 8,
                x: 0,
                y: 2
            )
    }
}

private struct ElevationShadowModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let level: Int

    func body(content: Content) -> some View {
        let opacity = 0.05 * Double(level)
        let radius = 2.0 * Double(level)
        let y = 1.0 * Double(level)

        return content
            .shadow(
                color: (Color.App.primary.color(for: colorScheme)).opacity(min(opacity, 0.2)),
                radius: radius,
                x: 0,
                y: y
            )
    }
}

// Common adaptive colors
extension AdaptiveColor {
    static let cardBackground = AdaptiveColor(
        light: Color(hex: "FFFFFF", opacity: 0.7),
        dark: Color(hex: "000000", opacity: 0.3)
    )

    static let hoverHighlight = AdaptiveColor(
        light: Color(hex: "000000", opacity: 0.05),
        dark: Color(hex: "FFFFFF", opacity: 0.05)
    )

    static let glassOverlay = AdaptiveColor(
        light: Color(hex: "FFFFFF", opacity: 0.5),
        dark: Color(hex: "FFFFFF", opacity: 0.1)
    )
}
