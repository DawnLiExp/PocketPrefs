//
//  SidebarView.swift
//  PocketPrefs
//
//  Sidebar navigation with mode selection
//

import SwiftUI

struct SidebarView: View {
    @Binding var currentMode: MainView.AppMode
    @State private var showingSettings = false
    @Environment(\.colorScheme) var colorScheme
    
    let modes: [MainView.AppMode] = [.backup, .restore]
    
    var body: some View {
        VStack(spacing: 12) {
            // Mode Selection Buttons - Vertical layout with icons on top
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
            
            // Settings Button - Same vertical layout
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
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.App.secondaryBackground.color(for: colorScheme),
                    Color.App.background.color(for: colorScheme)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(colorScheme == .dark ? 0.9 : 0.95)
        )
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .frame(width: 750, height: 500)
        }
    }
}

struct SidebarIconButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    
    // Three-tier brightness levels
    private var iconOpacity: Double {
        if isSelected { return 1.0 } // Brightest when selected
        if isHovered { return 0.8 } // Medium on hover
        return 0.5 // Dim when idle
    }
    
    private var textColor: Color {
        if isSelected { return Color.App.primary.color(for: colorScheme) }
        if isHovered { return Color.App.primary.color(for: colorScheme).opacity(0.8) }
        return Color.App.secondary.color(for: colorScheme)
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(
                        LinearGradient.appAccent(for: colorScheme)
                            .opacity(iconOpacity)
                    )
                    .frame(height: 24)
                
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(textColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(DesignConstants.Animation.quick) {
                isHovered = hovering
            }
        }
    }
}
