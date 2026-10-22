//
//  CustomBackupPicker.swift
//  PocketPrefs
//
//  Backup selection picker component
//

import SwiftUI

struct CustomBackupPicker: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(MainCoordinator.self) private var coordinator

    var body: some View {
        Group {
            if coordinator.currentBackups.isEmpty {
                Text("No_Backups_Found")
                    .font(DesignConstants.Typography.body)
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                            .fill(Color.App.tertiaryBackground.color(for: colorScheme).opacity(0.7)),
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                            .stroke(Color.App.lightSeparator.color(for: colorScheme).opacity(0.7), lineWidth: 1.0),
                    )
            } else {
                BackupSelectionMenu(
                    backups: coordinator.currentBackups, selectedBackup: coordinator.currentSelectedBackup,
                    label: "Select_Backup_Label", onSelect: coordinator.selectBackup)
            }
        }
    }
}

struct BackupSelectionMenu: View {
    let backups: [BackupInfo]
    let selectedBackup: BackupInfo?
    let label: LocalizedStringKey
    let onSelect: (BackupInfo) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Menu {
            ForEach(backups) { backup in
                Button {
                    onSelect(backup)
                } label: {
                    if backup.id == selectedBackup?.id {
                        Label(backup.formattedName, systemImage: "checkmark")
                    } else {
                        Text(backup.formattedName)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    if let selectedBackup {
                        Text(selectedBackup.selectionDate).font(DesignConstants.Typography.body)
                        Text(selectedBackup.selectionTime).font(DesignConstants.Typography.caption)
                            .monospacedDigit().foregroundStyle(.secondary)
                    } else {
                        Text("Restore_Select_Backup").font(DesignConstants.Typography.body)
                    }
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .medium))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                    .fill(Color.App.tertiaryBackground.color(for: colorScheme).opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                    .stroke(Color.App.lightSeparator.color(for: colorScheme).opacity(0.7), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text(label))
        .accessibilityValue(selectedBackup?.formattedName ?? String(localized: "Restore_Select_Backup"))
        .help(selectedBackup?.formattedName ?? String(localized: "Restore_Select_Backup"))
    }
}
