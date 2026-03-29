//
//  PresetAppsView.swift
//  PocketPrefs
//
//  Preset Apps management placeholder
//

import SwiftUI

struct PresetAppsView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        DualColumnSettingsLayout(leftWidth: 280) {
            // Left Panel - Preset Apps List
            VStack {
                Spacer()
                Text("PresetApps_List_Placeholder")
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.App.controlBackground.color(for: colorScheme))
        } right: {
            // Right Panel - Preset App Details
            VStack(spacing: 16) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))

                Text(String(localized: "Settings_Preset_ComingSoon", defaultValue: "Preset App Management\nComing soon."))
                    .font(DesignConstants.Typography.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.App.background.color(for: colorScheme))
        }
    }
}

#Preview {
    PresetAppsView()
        .frame(width: 820, height: 600)
}
