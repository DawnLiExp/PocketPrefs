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
       
            // Mode selection buttons with enhanced visual hierarchy
            VStack(spacing: 8) {
                ForEach(modes, id: \.self) { mode in
                    SidebarIconButton(
                        icon: mode.icon,
                        title: mode.displayName,
                        isSelected: currentMode == mode
                    ) {
                        withAnimation(DesignConstants.Animation.quick) {
                            currentMode = mode
                        }
                    }
                }
            }
            
            // Divider section
            dividerSection
            
            // Settings button with consistent styling
            SidebarIconButton(
                icon: "gearshape.2",
                title: NSLocalizedString("Sidebar_Settings", comment: ""),
                isSelected: false
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
                        .opacity(0.3)
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
    @State private var isPressing = false
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
            .scaleEffect(isPressing ? 0.96 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(DesignConstants.Animation.quick) {
                isHovered = hovering
            }
        }
        .pressEvents(
            onPress: {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressing = true
                }
            },
            onRelease: {
                withAnimation(.easeOut(duration: 0.2)) {
                    isPressing = false
                }
            }
        )
    }
    
    @ViewBuilder
    private var iconView: some View {
        Image(systemName: icon)
            .font(.system(size: 24, weight: .medium))
            .foregroundColor(iconColor)
            .shadow(
                color: isSelected ? iconColor.opacity(0.3) : .clear,
                radius: 2,
                x: 0,
                y: 1
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

// MARK: - Press Events Modifier

private struct PressEventsModifier: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        onPress()
                    }
                    .onEnded { _ in
                        onRelease()
                    }
            )
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEventsModifier(onPress: onPress, onRelease: onRelease))
    }
}

// MARK: - Preview

#Preview {
    SidebarView(currentMode: .constant(.backup))
        .frame(width: 76, height: 600)
        .enhancedSidebarBackground()
}
