//
//  ColorExtensions.swift
//  PocketPrefs
//
//  Created by Me2 on 2025/9/18.
//

import SwiftUI

// MARK: - Color Palette

extension Color {
    enum App {
        // Primary Colors
        static let accent = Color.accentColor
        static let primary = Color.primary
        static let secondary = Color.secondary

        // Semantic Colors
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue

        // Background Colors
        static let background = Color(NSColor.windowBackgroundColor)
        static let secondaryBackground = Color(NSColor.controlBackgroundColor)
        static let tertiaryBackground = Color(NSColor.underPageBackgroundColor)

        // Interactive Elements
        static let controlBackground = Color(NSColor.controlBackgroundColor)
        static let selectedControlBackground = Color(NSColor.selectedControlColor)
        static let hoverBackground = Color.accentColor.opacity(0.08)

        // Text Colors
        static let primaryText = Color(NSColor.labelColor)
        static let secondaryText = Color(NSColor.secondaryLabelColor)
        static let tertiaryText = Color(NSColor.tertiaryLabelColor)
        static let disabledText = Color(NSColor.disabledControlTextColor)

        // Separator
        static let separator = Color(NSColor.separatorColor)
        static let lightSeparator = Color(NSColor.separatorColor).opacity(0.5)

        // Status Colors
        static let installed = Color.green.opacity(0.8)
        static let notInstalled = Color.orange.opacity(0.8)
        static let processing = Color.blue.opacity(0.8)

        // Progress Colors
        static let progressTrack = Color.gray.opacity(0.2)
        static let progressFill = Color.accentColor
    }
}

// MARK: - Gradient Definitions

extension LinearGradient {
    static var appAccent: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(NSColor.systemBlue),
                Color(NSColor.systemTeal)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// 添加这些扩展到 View 而不是 LinearGradient
extension View {
    func sidebarBackground() -> some View {
        background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(NSColor.controlBackgroundColor),
                    Color(NSColor.windowBackgroundColor)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    func contentBackground() -> some View {
        background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Shadow Definitions

extension View {
    func softShadow() -> some View {
        shadow(
            color: Color.black.opacity(0.1),
            radius: 8,
            x: 0,
            y: 2
        )
    }

    func elevationShadow(_ level: Int = 1) -> some View {
        let opacity = 0.05 * Double(level)
        let radius = 2.0 * Double(level)
        let y = 1.0 * Double(level)

        return shadow(
            color: Color.black.opacity(min(opacity, 0.2)),
            radius: radius,
            x: 0,
            y: y
        )
    }
}

// MARK: - Adaptive Colors

struct AdaptiveColor {
    let light: Color
    let dark: Color

    func color(for scheme: ColorScheme) -> Color {
        scheme == .dark ? dark : light
    }
}

// Common adaptive colors
extension AdaptiveColor {
    static let cardBackground = AdaptiveColor(
        light: Color.white.opacity(0.7),
        dark: Color.black.opacity(0.3)
    )

    static let hoverHighlight = AdaptiveColor(
        light: Color.black.opacity(0.05),
        dark: Color.white.opacity(0.05)
    )

    static let glassOverlay = AdaptiveColor(
        light: Color.white.opacity(0.5),
        dark: Color.white.opacity(0.1)
    )
}
