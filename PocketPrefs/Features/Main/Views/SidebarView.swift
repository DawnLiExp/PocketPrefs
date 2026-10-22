//
//  SidebarView.swift
//  PocketPrefs
//
//  Sidebar navigation with mode selection and enhanced glass effects
//

import SwiftUI

struct SidebarView: View {
    @Binding var currentMode: MainView.AppMode
    @State private var showingSettings = false
    @Environment(\.colorScheme) var colorScheme
    
    let modes: [MainView.AppMode] = [.backup, .restore]
    
    var body: some View {
        VStack(spacing: 12) {
            // Top spacer for title bar area
            Spacer()
                .frame(height: 20)
            // Mode selection buttons with enhanced visual hierarchy
            VStack(spacing: 8) {
                ForEach(modes, id: \.self) { mode in
                    SidebarIconButton(
                        icon: mode.icon,
                        title: mode.displayName,
                        isSelected: currentMode == mode,
                    ) {
                        currentMode = mode
                    }
                }
            }
            
            // Divider section
            dividerSection
            
            // Settings button with consistent styling
            SidebarIconButton(
                icon: "gearshape.2",
                title: String(localized: "Sidebar_Settings"),
                isSelected: false,
            ) {
                showingSettings = true
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .frame(width: DesignConstants.Layout.sidebarWidth)
        .frame(maxHeight: .infinity)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .frame(width: 750, height: 500)
        }
    }
    
    @ViewBuilder
    private var dividerSection: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 16)
            
            Rectangle()
                .fill(
                    Color.App.lightSeparator
                        .color(for: colorScheme)
                        .opacity(0.3),
                )
                .frame(height: 0.5)
                .padding(.horizontal, 18)
            
            Spacer()
                .frame(height: 16)
        }
    }
}

// MARK: - Enhanced Sidebar Icon Button

struct SidebarIconButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme
    
    // Enhanced visual state management
    private var iconColor: Color {
        let baseColor = Color.App.accent.color(for: colorScheme)
        
        if isSelected {
            return baseColor
        } else if isHovered {
            return baseColor.opacity(0.75)
        } else {
            return baseColor.opacity(0.45)
        }
    }
    
    private var textColor: Color {
        let baseColor = Color.App.primaryText.color(for: colorScheme)
        
        if isSelected {
            return baseColor
        } else if isHovered {
            return baseColor.opacity(0.8)
        } else {
            return baseColor.opacity(0.55)
        }
    }
    
    private var backgroundOpacity: Double {
        if isSelected {
            return 0.12
        } else if isHovered {
            return 0.06
        } else {
            return 0.0
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                iconView
                textView
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(SidebarPressStyle())
        .keyboardFocusOutline()
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover { hovering in
            withAnimation(DesignConstants.Animation.quick) {
                isHovered = hovering
            }
        }
    }
    
    @ViewBuilder
    private var iconView: some View {
        Image(systemName: icon)
            .font(.system(size: 22, weight: .medium))
            .foregroundColor(iconColor)
            .shadow(
                color: isSelected ? iconColor.opacity(0.3) : .clear,
                radius: 2,
                x: 0,
                y: 1,
            )
    }
    
    @ViewBuilder
    private var textView: some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(textColor)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

private struct SidebarPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Preview

#Preview {
    SidebarView(currentMode: .constant(.backup))
        .frame(width: 76, height: 600)
        .enhancedSidebarBackground()
}
