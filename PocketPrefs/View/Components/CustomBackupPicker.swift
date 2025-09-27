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

    /// Formats the backup name for display.
    /// It removes the "Backup_" prefix and attempts to reformat the timestamp into a more human-readable, localized string.
    /// - Parameter name: The original backup name string (e.g., "Backup_2025-09-27_14-35-00").
    /// - Returns: The formatted backup name (e.g., "2025年9月27日 下午2:35:00").
    private func formatBackupName(_ name: String) -> String {
        let prefix = "Backup_"
        guard name.hasPrefix(prefix) else {
            return name // Return original if prefix not found
        }

        let dateString = name.replacingOccurrences(of: prefix, with: "")

        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX") // Use POSIX locale for consistent parsing

        if let date = inputFormatter.date(from: dateString) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateStyle = .long
            outputFormatter.timeStyle = .medium
            outputFormatter.locale = Locale.current // Use current locale for user-friendly display
            return outputFormatter.string(from: date)
        } else {
            return dateString // Fallback to raw date string if parsing fails
        }
    }
}
