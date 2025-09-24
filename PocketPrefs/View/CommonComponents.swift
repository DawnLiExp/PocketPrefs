//
//  CommonComponents.swift
//  PocketPrefs
//
//  Reusable UI components and styles
//

import SwiftUI

// MARK: - Progress View

struct ProgressView: View {
    let progress: Double
    @Environment(\.colorScheme) var colorScheme
    @State private var rotation: Double = 0
    @State private var pulseScale: Double = 1.0

    var body: some View {
        VStack(spacing: 32) {
            CircularProgressView(progress: progress)
                .frame(width: 140, height: 140)

            VStack(spacing: 12) {
                Text(NSLocalizedString("Common_Processing", comment: ""))
                    .font(DesignConstants.Typography.headline)
                    .foregroundColor(Color.App.primary.color(for: colorScheme))

                Text("\(Int(progress * 100))%")
                    .font(DesignConstants.Typography.largeTitle)
                    .foregroundColor(Color.App.accent.color(for: colorScheme))
                    .scaleEffect(pulseScale)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseScale)
                    .onAppear {
                        pulseScale = 1.05
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial.opacity(0.8))
        .background(
            (Color.App.unifiedBackground.color(for: colorScheme)).opacity(0.3)
        )
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    @Environment(\.colorScheme) var colorScheme
    @State private var decorativeRotation: Double = 0

    var body: some View {
        ZStack {
            // Background Track
            Circle()
                .stroke(
                    Color.App.progressTrack.color(for: colorScheme),
                    lineWidth: 8
                )

            // Progress Arc with Gradient
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.App.accent.color(for: colorScheme),
                            Color.App.accent.color(for: colorScheme).opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(
                        lineWidth: 8,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)

            // Decorative Ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.App.accent.color(for: colorScheme).opacity(0.3),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(decorativeRotation))
                .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: decorativeRotation)
                .onAppear {
                    decorativeRotation = 360
                }

            // Center Icon with Rotation
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(Color.App.accent.color(for: colorScheme))
                .rotationEffect(.degrees(progress * 360))
                .animation(.easeInOut(duration: 0.8), value: progress)
                .shadow(
                    color: Color.App.accent.color(for: colorScheme).opacity(0.3),
                    radius: 4,
                    x: 0,
                    y: 2
                )
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let text: String
    let color: Color
    var style: BadgeStyle = .normal

    enum BadgeStyle {
        case normal, compact
    }

    var body: some View {
        Text(text)
            .font(style == .compact ? DesignConstants.Typography.caption : DesignConstants.Typography.body)
            .foregroundColor(color)
            .padding(.horizontal, style == .compact ? 6 : 8)
            .padding(.vertical, style == .compact ? 2 : 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignConstants.Typography.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                    .fill(
                        (Color.App.accent.color(for: colorScheme))
                            .opacity(isEnabled ? (isHovered ? 0.9 : 1.0) : 0.5)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .shadow(
                color: (Color.App.accent.color(for: colorScheme)).opacity(isEnabled ? (isHovered ? 0.4 : 0.2) : 0.1),
                radius: isHovered ? 10 : 5,
                x: 0,
                y: isHovered ? 4 : 2
            )
            .animation(DesignConstants.Animation.smooth, value: configuration.isPressed || isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    @Environment(\.colorScheme) var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignConstants.Typography.headline)
            .foregroundColor(isEnabled ? (Color.App.primary.color(for: colorScheme)) : (Color.App.secondary.color(for: colorScheme)))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                    .fill((Color.App.tertiaryBackground.color(for: colorScheme)).opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                    .stroke(Color.App.lightSeparator.color(for: colorScheme), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(DesignConstants.Animation.quick, value: configuration.isPressed)
    }
}
