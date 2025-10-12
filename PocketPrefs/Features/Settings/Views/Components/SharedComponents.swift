//
//  SharedComponents.swift
//  PocketPrefs
//
//  Shared UI components across Settings views
//

import SwiftUI

// MARK: - Settings Title Bar

struct SettingsTitleBar: View {
    let onClose: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            Text(NSLocalizedString("Settings_Title", comment: ""))
                .font(DesignConstants.Typography.title)
                .foregroundColor(Color.App.primary.color(for: colorScheme))
            
            Spacer()
            
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.App.secondaryBackground.color(for: colorScheme))
    }
}

// MARK: - Settings Toolbar

struct SettingsToolbar: View {
    @Binding var searchText: String
    let selectedCount: Int
    let onAddApp: () -> Void
    let onDeleteSelected: () -> Void
    let customAppManager: CustomAppManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
                
                TextField(NSLocalizedString("Search_Placeholder", comment: "Search apps..."), text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.App.secondary.color(for: colorScheme))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.App.tertiaryBackground.color(for: colorScheme).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Action buttons
            HStack {
                Button(action: onAddApp) {
                    Label(NSLocalizedString("Settings_Add_App", comment: ""),
                          systemImage: "plus")
                        .font(DesignConstants.Typography.body)
                }
                .buttonStyle(.bordered)
                
                if selectedCount > 0 {
                    Button(action: onDeleteSelected) {
                        Label(String(format: NSLocalizedString("Settings_Delete_Selected", comment: ""),
                                     selectedCount),
                              systemImage: "trash")
                            .font(DesignConstants.Typography.body)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.App.error.color(for: colorScheme))
                }
                
                Spacer()
            }
            
            HStack {
                Toggle(isOn: Binding(
                    get: { !customAppManager.customApps.isEmpty && customAppManager.selectedAppIds.count == customAppManager.customApps.count },
                    set: { newValue in
                        if newValue {
                            Task {
                                await customAppManager.selectAll()
                            }
                        } else {
                            customAppManager.deselectAll()
                        }
                    },
                )) {
                    Text(NSLocalizedString("Select_All", comment: ""))
                        .font(DesignConstants.Typography.body)
                }
                .toggleStyle(.checkbox)
                
                Spacer()
                
                Text(String(format: NSLocalizedString("Selected_Count", comment: ""), customAppManager.selectedAppIds.count, customAppManager.customApps.count))
                    .font(DesignConstants.Typography.caption)
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }
        }
        .padding(12)
    }
}

// MARK: - Empty States

struct EmptyAppsListView: View {
    let searchActive: Bool
    let searchText: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: searchActive ? "magnifyingglass" : "plus.app")
                .font(.system(size: 48))
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
            
            Text(searchActive ?
                String(format: NSLocalizedString("Search_No_Results", comment: ""), searchText) :
                NSLocalizedString("Settings_No_Custom_Apps", comment: ""))
                .font(DesignConstants.Typography.headline)
                .foregroundColor(Color.App.primary.color(for: colorScheme))
            
            Text(searchActive ?
                NSLocalizedString("Search_Try_Different_Keyword", comment: "") :
                NSLocalizedString("Settings_Add_First_App_Hint", comment: ""))
                .font(DesignConstants.Typography.caption)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 48))
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
            
            Text(NSLocalizedString("Settings_Select_App_To_Configure", comment: ""))
                .font(DesignConstants.Typography.headline)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
