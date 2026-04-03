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
            Text("Settings_Title")
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
        .background(Color.App.contentAreaBackground.color(for: colorScheme))
    }
}

// MARK: - Settings Toolbar

struct SettingsToolbar: View {
    @Binding var searchText: String
    let selectedCount: Int
    let onAddApp: () -> Void
    let onDeleteSelected: () -> Void
    let customAppManager: CustomAppManager
    @FocusState private var isSearchFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
                    .font(.system(size: 14))
                    .padding(.leading, 12)
                    .padding(.trailing, 8)

                TextField("Search_Placeholder", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .font(DesignConstants.Typography.body)

                Spacer(minLength: 8)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.App.secondary.color(for: colorScheme))
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 12)
                }
            }
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                    .fill(Color.App.tertiaryBackground.color(for: colorScheme).opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                    .stroke(
                        Color.App.lightSeparator.color(for: colorScheme).opacity(0.7),
                        lineWidth: 1.0
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isSearchFocused)

            // Action buttons
            HStack {
                Button(action: onAddApp) {
                    Label("Settings_Add_App", systemImage: "plus")
                        .font(DesignConstants.Typography.body)
                }
                .buttonStyle(ToolbarButtonStyle(isDestructive: false))
                
                if selectedCount > 0 {
                    Button(action: onDeleteSelected) {
                        Label(
                            String(localized: "Settings_Delete_Selected", defaultValue: "Delete \(selectedCount) Selected"),
                            systemImage: "trash"
                        )
                        .font(DesignConstants.Typography.body)
                    }
                    .buttonStyle(ToolbarButtonStyle(isDestructive: true))
                }
                
                Spacer()
            }
            
            HStack {
                Toggle(isOn: Binding(
                    get: {
                        !customAppManager.customApps.isEmpty &&
                            customAppManager.selectedAppIds.count == customAppManager.customApps.count
                    },
                    set: { newValue in
                        if newValue {
                            Task { await customAppManager.selectAll() }
                        } else {
                            customAppManager.deselectAll()
                        }
                    },
                )) {
                    Text("Select_All")
                        .font(DesignConstants.Typography.body)
                }
                .toggleStyle(CustomCheckboxToggleStyle())
                
                Spacer()
                
                Text(String(localized: "Settings_Selected_Count", defaultValue: "\(customAppManager.selectedAppIds.count) of \(customAppManager.customApps.count) selected"))
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
                String(localized: "Settings_Search_No_Results", defaultValue: "No results for \"\(searchText)\"") :
                String(localized: "Settings_No_Custom_Apps", defaultValue: "No custom apps added"))
                .font(DesignConstants.Typography.headline)
                .foregroundColor(Color.App.primary.color(for: colorScheme))
            
            Text(searchActive ?
                "Search_Try_Different_Keyword" :
                "Settings_Add_First_App_Hint")
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
            
            Text("Settings_Select_App_To_Configure")
                .font(DesignConstants.Typography.headline)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
