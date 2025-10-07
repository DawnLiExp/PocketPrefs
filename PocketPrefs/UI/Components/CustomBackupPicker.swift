//
//  CustomBackupPicker.swift
//  PocketPrefs
//
//  Backup selection picker component
//

import SwiftUI

struct CustomBackupPicker: View {
    @ObservedObject var coordinator: MainCoordinator
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Group {
            if coordinator.availableBackups.isEmpty {
                Text(NSLocalizedString("No_Backups_Found", comment: "No backups available"))
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
                    Text(NSLocalizedString("Select_Backup_Label", comment: ""))
                        .font(DesignConstants.Typography.body)
                        .foregroundColor(Color.App.primary.color(for: colorScheme))

                    Menu {
                        ForEach(coordinator.availableBackups) { backup in
                            Button {
                                coordinator.selectBackup(backup)
                            } label: {
                                Text(backup.formattedName)
                            }
                        }
                    } label: {
                        Text(coordinator.currentSelectedBackup?.formattedName ?? NSLocalizedString("Restore_Select_Backup", comment: ""))
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
