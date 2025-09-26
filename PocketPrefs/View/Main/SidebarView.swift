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
        .sidebarBackground()
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
    @Environment(\.colorScheme) private var colorScheme
    
    // Enhanced opacity levels for better visual hierarchy
    private var iconOpacity: Double {
        if isSelected { return 1.0 }
        if isHovered { return 0.75 }
        return 0.45
    }
    
    private var textOpacity: Double {
        if isSelected { return 1.0 }
        if isHovered { return 0.8 }
        return 0.55
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(
                        Color.App.accent.color(for: colorScheme)
                            .opacity(iconOpacity)
                    )
                
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(
                        Color.App.primaryText.color(for: colorScheme)
                            .opacity(textOpacity)
                    )
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(DesignConstants.Animation.quick) {
                isHovered = hovering
            }
        }
    }
}
