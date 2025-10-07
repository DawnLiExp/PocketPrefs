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
        Menu {
            if coordinator.availableBackups.isEmpty {
                Text(NSLocalizedString("Restore_No_Backups_Available", comment: ""))
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
            } else {
                ForEach(coordinator.availableBackups) { backup in
                    Button {
                        coordinator.selectBackup(backup)
                    } label: {
                        Text(backup.formattedName)
                    }
                }
            }
        } label: {
            HStack {
                Text(coordinator.currentSelectedBackup?.formattedName ?? NSLocalizedString("Restore_Select_Backup", comment: ""))
                    .font(DesignConstants.Typography.body)
                    .foregroundColor(Color.App.primary.color(for: colorScheme))

                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
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
    }
}
