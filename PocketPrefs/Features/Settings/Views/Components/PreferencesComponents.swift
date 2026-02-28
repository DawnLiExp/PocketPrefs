//
//  PreferencesComponents.swift
//  PocketPrefs
//
//  Preferences-specific UI components
//

import AppKit
import SwiftUI

// MARK: - Appearance Section

struct AppearanceSection: View {
    var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        @Bindable var themeManager = themeManager
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("Settings_Appearance", comment: ""))
                .font(DesignConstants.Typography.headline)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
                .padding(.horizontal, 4)
            
            HStack {
                Label(
                    NSLocalizedString("Menu_Theme", comment: ""),
                    systemImage: "paintpalette",
                )
                .font(DesignConstants.Typography.body)
                .foregroundColor(Color.App.primary.color(for: colorScheme))
                
                Spacer()
                
                Picker("", selection: $themeManager.currentTheme) {
                    ForEach(Theme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.radioGroup)
                .horizontalRadioGroupLayout()
                .onChange(of: themeManager.currentTheme) { _, newTheme in
                    themeManager.setTheme(newTheme)
                }
            }
            .padding(16)
            .sectionBackground()
        }
    }
}

// MARK: - Language Section

struct LanguageSection: View {
    var languageManager: LanguageManager
    let onLanguageChange: (AppLanguage) -> Void
    @State private var selectedLanguage: AppLanguage
    @Environment(\.colorScheme) var colorScheme
    
    init(languageManager: LanguageManager, onLanguageChange: @escaping (AppLanguage) -> Void) {
        self.languageManager = languageManager
        self.onLanguageChange = onLanguageChange
        _selectedLanguage = State(initialValue: languageManager.currentLanguage)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text(NSLocalizedString("Settings_Language", comment: ""))
                    .font(DesignConstants.Typography.headline)
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
                
                Text(NSLocalizedString("Settings_Language_Restart_Hint", comment: ""))
                    .font(DesignConstants.Typography.caption)
                    .foregroundColor(Color.App.secondary.color(for: colorScheme).opacity(0.7))
            }
            .padding(.horizontal, 4)
            
            HStack {
                Label(
                    NSLocalizedString("Settings_Language", comment: ""),
                    systemImage: "globe",
                )
                .font(DesignConstants.Typography.body)
                .foregroundColor(Color.App.primary.color(for: colorScheme))
                
                Spacer()
                
                Picker("", selection: $selectedLanguage) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.radioGroup)
                .horizontalRadioGroupLayout()
                .onChange(of: selectedLanguage) { oldValue, newValue in
                    if oldValue != newValue {
                        onLanguageChange(newValue)
                    }
                }
            }
            .padding(16)
            .sectionBackground()
        }
    }
}

// MARK: - Backup Location Section

struct BackupLocationSection: View {
    var preferencesManager: PreferencesManager
    @Binding var showingDirectoryPicker: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    NSLocalizedString("Preferences_Backup_Location", comment: ""),
                    systemImage: "folder.badge.gearshape",
                )
                .font(DesignConstants.Typography.body)
                .foregroundColor(Color.App.primary.color(for: colorScheme))
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                StatusIndicator(status: preferencesManager.directoryStatus)
                
                Text(preferencesManager.getDisplayPath())
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button(action: openInFinder) {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 16))
                        .foregroundColor(Color.App.secondary.color(for: colorScheme))
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("Show_In_Finder", comment: ""))
            }
            .padding(12)
            .background(Color.App.tertiaryBackground.color(for: colorScheme).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            if case .invalid(let reason) = preferencesManager.directoryStatus {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color.App.warning.color(for: colorScheme))
                    Text(reason)
                        .font(DesignConstants.Typography.caption)
                        .foregroundColor(Color.App.warning.color(for: colorScheme))
                }
            }
            
            Button(action: { showingDirectoryPicker = true }) {
                Label(
                    NSLocalizedString("Preferences_Choose_Directory", comment: ""),
                    systemImage: "folder.badge.plus",
                )
                .font(DesignConstants.Typography.headline)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(16)
        .sectionBackground()
    }
    
    private func openInFinder() {
        let path = preferencesManager.getBackupDirectory()
        guard FileManager.default.fileExists(atPath: path) else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
}

// MARK: - Status Indicator

struct StatusIndicator: View {
    let status: PreferencesManager.DirectoryStatus
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            switch status {
            case .unknown, .creating:
                SwiftUI.ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
                
            case .valid:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.App.success.color(for: colorScheme))
                
            case .invalid:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Color.App.error.color(for: colorScheme))
            }
        }
        .font(.system(size: 16))
    }
}
