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
    let messageHistory: [String]
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 32) {
            CircularProgressView(progress: progress)
                .frame(width: 160, height: 160)

            // Scrolling message history (max 3 lines)
            VStack(spacing: 8) {
                ForEach(messageHistory.indices, id: \.self) { index in
                    Text(messageHistory[index])
                        .font(DesignConstants.Typography.body)
                        .foregroundColor(
                            index == messageHistory.count - 1
                                ? Color.App.primary.color(for: colorScheme)
                                : Color.App.secondary.color(for: colorScheme).opacity(0.7)
                        )
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
            }
            .frame(height: 80)
            .animation(.easeInOut(duration: 0.3), value: messageHistory)
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
                    lineWidth: 6
                )

            // Progress Arc with Gradient - smooth animation
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
                        lineWidth: 6,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.7), value: progress)

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
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(decorativeRotation))
                .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: decorativeRotation)
                .onAppear {
                    decorativeRotation = 360
                }

            // Center percentage number
            Text("\(Int(progress * 100))%")
                .font(.system(size: 38, weight: .light, design: .rounded))
                .foregroundColor(Color.App.accent.color(for: colorScheme))
                .animation(.easeOut(duration: 0.3), value: progress)
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
            .foregroundColor(Color.App.accent.color(for: colorScheme))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.App.accent.color(for: colorScheme).opacity(isHovered ? 0.15 : 0.1),
                                Color.App.accent.color(for: colorScheme).opacity(isHovered ? 0.1 : 0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                            .stroke(
                                Color.App.accent.color(for: colorScheme),
                                lineWidth: 0.6
                            )
                    )
            )
            .opacity(isEnabled ? 1.0 : 0.5)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
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
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}
