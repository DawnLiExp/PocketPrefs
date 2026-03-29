//
//  SettingsSidebarView.swift
//  PocketPrefs
//

import SwiftUI

struct SettingsSidebarView: View {
    @Binding var selectedTab: SettingsTab
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 20)
            
            VStack(spacing: 4) {
                SettingsSidebarItem(
                    icon: "gear",
                    title: String(localized: "Settings_Tab_General", defaultValue: "General"),
                    isSelected: selectedTab == .general
                ) { selectedTab = .general }
                
                SettingsSidebarItem(
                    icon: "app.badge.fill",
                    title: String(localized: "Settings_Tab_Custom_Apps", defaultValue: "Custom Apps"),
                    isSelected: selectedTab == .customApps
                ) { selectedTab = .customApps }
            }
            
            VStack(spacing: 0) {
                Spacer().frame(height: 12)
                Divider().padding(.horizontal, 16)
                Spacer().frame(height: 12)
            }
            
            SettingsSidebarItem(
                icon: "square.grid.2x2.fill",
                title: String(localized: "Settings_Tab_Preset_Apps", defaultValue: "Preset Apps"),
                isSelected: selectedTab == .presetApps
            ) { selectedTab = .presetApps }
            .disabled(true)
            .opacity(0.35)
            
            Spacer()
        }
        .padding(.vertical, 12)
    }
}

private struct SettingsSidebarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? Color.App.accent.color(for: colorScheme) : Color(NSColor.labelColor))
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.App.accent.color(for: colorScheme).opacity(0.12) : (isHovered ? Color.App.hoverBackground.color(for: colorScheme) : Color.clear))
        )
        .padding(.horizontal, 10)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}
