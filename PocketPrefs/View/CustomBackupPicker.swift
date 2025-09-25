//
//  CustomBackupPicker.swift
//  PocketPrefs
//
//  Minimalist backup selector with adaptive color scheme
//

import SwiftUI

/// A custom backup selector view that replaces the system-style picker with a more minimalist design.
/// It displays the currently selected backup and, when clicked, reveals a menu of available backups.
struct CustomBackupPicker: View {
    @ObservedObject var backupManager: BackupManager
    @Environment(\.colorScheme) var colorScheme
    @State private var isMenuPresented: Bool = false

    var body: some View {
        Group {
            if backupManager.availableBackups.isEmpty {
                Text(NSLocalizedString("No_Backups_Found", comment: "No backups available"))
                    .font(DesignConstants.Typography.body)
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                            .fill(Color.App.tertiaryBackground.color(for: colorScheme).opacity(0.7))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                            .stroke(Color.App.lightSeparator.color(for: colorScheme).opacity(0.7), lineWidth: 1.0)
                    )
            } else {
                HStack(spacing: 8) {
                    Text(NSLocalizedString("Select_Backup_Label", comment: ""))
                        .font(DesignConstants.Typography.body)
                        .foregroundColor(Color.App.primary.color(for: colorScheme))

                    Menu {
                        ForEach(backupManager.availableBackups) { backup in
                            Button {
                                backupManager.selectBackup(backup)
                            } label: {
                                Text(formatBackupName(backup.name))
                            }
                        }
                    } label: {
                        HStack {
                            Text(backupManager.selectedBackup.map { formatBackupName($0.name) } ?? "Select a backup")
                                .font(DesignConstants.Typography.body)
                                .foregroundColor(backupManager.selectedBackup != nil ? Color.App.primary.color(for: colorScheme) : Color.App.secondary.color(for: colorScheme))

                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                                .fill(Color.App.tertiaryBackground.color(for: colorScheme).opacity(0.7))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                                .stroke(Color.App.lightSeparator.color(for: colorScheme).opacity(0.7), lineWidth: 1.0)
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Formats the backup name by removing the "Backup_" prefix.
    /// - Parameter name: The original backup name string.
    /// - Returns: The formatted backup name.
    private func formatBackupName(_ name: String) -> String {
        name.replacingOccurrences(of: "Backup_", with: "")
    }
}
