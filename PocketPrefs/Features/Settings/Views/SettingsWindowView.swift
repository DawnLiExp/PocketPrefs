//
//  SettingsWindowView.swift
//  PocketPrefs
//

import SwiftUI

enum SettingsTab: Hashable {
    case general
    case customApps
    case presetApps
}

struct SettingsWindowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: SettingsTab = .general
    
    @State private var customAppManager = CustomAppManager()
    @State private var importExportManager = ImportExportManager()
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Fixed 140px custom sidebar with Glassmorphism
                SettingsSidebarView(selectedTab: $selectedTab)
                    .frame(width: 140)
                    .background(Material.regular)
                    .ignoresSafeArea(.all)
                
                Divider()
                
                // Content area
                contentView
                    .frame(width: 820, height: 590)
                    .background(Color.App.background.color(for: colorScheme))
            }
            .frame(height: 590)
            
            Divider()
            
            // Bottom Action Bar to conform to macOS HIG sheet behavior
            HStack {
                Spacer()
                Button(String(localized: "Settings_Done", defaultValue: "Done")) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .frame(height: 50)
            .background(Color.App.secondaryBackground.color(for: colorScheme))
        }
        .frame(width: 960, height: 640)
        .onDisappear {
            SettingsEventPublisher.shared.publishDidClose()
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        Group {
            switch selectedTab {
            case .general:
                GeneralSettingsView()
            case .customApps:
                Text("Custom Apps Placeholder")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .presetApps:
                Text("Preset Apps Placeholder")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .id(selectedTab) // ID allows transition per tab
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeOut(duration: 0.2), value: selectedTab)
    }
}
