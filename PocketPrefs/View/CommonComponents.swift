
//
//  CommonComponents.swift
//  PocketPrefs
//
//  Created by Me2 on 2025/9/18.
//

import SwiftUI

// MARK: - Progress View

struct ProgressView: View {
    let progress: Double
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            CircularProgressView(progress: progress)
                .frame(width: 120, height: 120)

            VStack(spacing: 8) {
                Text(NSLocalizedString("Common_Processing", comment: ""))
                    .font(DesignConstants.Typography.headline)
                    .foregroundColor(Color.App.primary.color(for: colorScheme))

                Text("\(Int(progress * 100))%")
                    .font(DesignConstants.Typography.largeTitle)
                    .foregroundStyle(LinearGradient.appAccent(for: colorScheme))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    Color.App.progressTrack.color(for: colorScheme),
                    lineWidth: 12
                )

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient.appAccent(for: colorScheme),
                    style: StrokeStyle(
                        lineWidth: 12,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(DesignConstants.Animation.standard, value: progress)

            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 32))
                .foregroundStyle(LinearGradient.appAccent(for: colorScheme))
                .rotationEffect(.degrees(progress * 360))
                .animation(DesignConstants.Animation.standard, value: progress)
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
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    @Environment(\.colorScheme) var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignConstants.Typography.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                LinearGradient.appAccent(for: colorScheme)
                    .opacity(isEnabled ? 1 : 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(DesignConstants.Animation.quick, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    @Environment(\.colorScheme) var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignConstants.Typography.headline)
            .foregroundColor(isEnabled ? Color.App.primary.color(for: colorScheme) : Color.App.secondary.color(for: colorScheme))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Color.App.secondaryBackground.color(for: colorScheme)
                    .opacity(isEnabled ? 0.5 : 0.3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                    .stroke(Color.App.separator.color(for: colorScheme), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(DesignConstants.Animation.quick, value: configuration.isPressed)
    }
}
