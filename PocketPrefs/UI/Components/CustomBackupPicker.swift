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
                HStack(spacing: 8) {
                    Text("Select_Backup_Label")
                        .font(DesignConstants.Typography.body)
                        .foregroundColor(Color.App.primary.color(for: colorScheme))

                    Menu {
                        ForEach(coordinator.currentBackups) { backup in
                            Button {
                                coordinator.selectBackup(backup)
                            } label: {
                                Text(backup.formattedName)
                            }
                        }
                    } label: {
                        Text(coordinator.currentSelectedBackup?.formattedName ?? String(localized: "Restore_Select_Backup", defaultValue: "Select a backup"))
                            .font(DesignConstants.Typography.body)
                            .foregroundColor(Color.App.primary.color(for: colorScheme))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                                    .fill(Color.App.tertiaryBackground.color(for: colorScheme).opacity(0.7)),
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                                    .stroke(Color.App.lightSeparator.color(for: colorScheme).opacity(0.7), lineWidth: 1.0),
                            )
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
