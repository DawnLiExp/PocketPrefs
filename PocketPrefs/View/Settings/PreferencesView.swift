//
//  PreferencesView.swift
//  PocketPrefs
//
//  Application preferences interface
//

import SwiftUI

struct PreferencesView: View {
    @StateObject private var preferencesManager = PreferencesManager.shared
    @State private var showingDirectoryPicker = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // General Section
                VStack(alignment: .leading, spacing: 16) {
                    Text(NSLocalizedString("Preferences_General", comment: ""))
                        .font(DesignConstants.Typography.headline)
                        .foregroundColor(Color.App.secondary.color(for: colorScheme))
                        .padding(.horizontal, 4)
                    
                    BackupLocationSection(
                        preferencesManager: preferencesManager,
                        showingDirectoryPicker: $showingDirectoryPicker,
                    )
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.App.background.color(for: colorScheme))
        .fileImporter(
            isPresented: $showingDirectoryPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false,
        ) { result in
            Task {
                await handleDirectorySelection(result)
            }
        }
    }
    
    @MainActor
    private func handleDirectorySelection(_ result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            await preferencesManager.setBackupDirectory(url.path)
            
        case .failure(let error):
            print("Directory selection error: \(error)")
        }
    }
}

// MARK: - Backup Location Section

struct BackupLocationSection: View {
    @ObservedObject var preferencesManager: PreferencesManager
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
            
            // Path display with status
            HStack(spacing: 12) {
                StatusIndicator(status: preferencesManager.directoryStatus)
                
                Text(preferencesManager.getDisplayPath())
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Color.App.tertiaryBackground.color(for: colorScheme).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Status message
            if case .invalid(let reason) = preferencesManager.directoryStatus {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color.App.warning.color(for: colorScheme))
                    Text(reason)
                        .font(DesignConstants.Typography.caption)
                        .foregroundColor(Color.App.warning.color(for: colorScheme))
                }
            }
            
            // Choose button
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
        .background(Color.App.tertiaryBackground.color(for: colorScheme).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.Layout.cornerRadius))
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

// MARK: - Preview

#Preview {
    PreferencesView()
        .frame(width: 750, height: 500)
}
