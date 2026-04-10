//
//  RestoreDetailView.swift
//  PocketPrefs
//
//  Restore mode detail views
//

import SwiftUI

// MARK: - RestorePlaceholderView

struct RestorePlaceholderView: View {
    var viewModel: DetailViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.selectedBackup != nil {
                RestoreDetailContent(viewModel: viewModel)
            } else {
                RestoreEmptyDetail()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - RestoreDetailContent

struct RestoreDetailContent: View {
    var viewModel: DetailViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if let backup = viewModel.selectedBackup {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "archivebox.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.App.accent.color(for: colorScheme))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(backup.formattedName)
                                .font(DesignConstants.Typography.title)

                            Text(String(localized: "Detail_Restore_Backup_App_Count", defaultValue: "\(backup.apps.count) apps"))
                                .font(DesignConstants.Typography.caption)
                                .foregroundColor(Color.App.secondary.color(for: colorScheme))
                        }

                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            String(localized: "Detail_Restore_Selected_Apps_Count", defaultValue: "\(viewModel.selectedRestoreAppsCount) apps selected"),
                            systemImage: "checkmark.circle.fill",
                        )
                        .font(DesignConstants.Typography.body)
                        .foregroundColor(
                            viewModel.selectedRestoreAppsCount > 0
                                ? Color.App.success.color(for: colorScheme)
                                : Color.App.secondary.color(for: colorScheme),
                        )

                        Label(
                            String(localized: "Detail_Restore_Uninstalled_Apps_Count", defaultValue: "\(viewModel.uninstalledSelectedCount) uninstalled apps"),
                            systemImage: "exclamationmark.triangle.fill",
                        )
                        .font(DesignConstants.Typography.body)
                        .foregroundColor(
                            viewModel.uninstalledSelectedCount > 0
                                ? Color.App.warning.color(for: colorScheme)
                                : Color.App.secondary.color(for: colorScheme),
                        )
                    }
                }
                .padding(20)

                if viewModel.hasSelectedRestoreApps {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Detail_Restore_Will_Restore_Apps")
                                .font(DesignConstants.Typography.headline)
                                .padding(.bottom, 8)

                            ForEach(backup.apps.filter(\.isSelected)) { app in
                                HStack {
                                    Image(systemName: app.isCurrentlyInstalled
                                        ? "checkmark.circle"
                                        : "exclamationmark.circle")
                                        .foregroundColor(
                                            app.isCurrentlyInstalled
                                                ? Color.App.success.color(for: colorScheme)
                                                : Color.App.warning.color(for: colorScheme),
                                        )

                                    Text(app.name)
                                        .font(DesignConstants.Typography.body)

                                    if !app.isCurrentlyInstalled {
                                        Text("Detail_Restore_App_Not_Installed_Badge")
                                            .font(DesignConstants.Typography.caption)
                                            .foregroundColor(Color.App.warning.color(for: colorScheme))
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 48))
                            .foregroundColor(Color.App.accent.color(for: colorScheme).opacity(0.6))

                        Text("Detail_Restore_No_Apps_Selected")
                            .font(DesignConstants.Typography.headline)
                            .foregroundColor(Color.App.secondary.color(for: colorScheme))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Spacer()

                HStack {
                    Spacer()

                    Button(action: { viewModel.performRestore() }) {
                        Label(
                            "Detail_Restore_Action_Restore_Selected",
                            systemImage: "arrow.down.circle.fill",
                        )
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!viewModel.hasSelectedRestoreApps)
                }
                .padding(22)
            }
        } else {
            RestoreEmptyDetail()
        }
    }
}

// MARK: - RestoreEmptyDetail

struct RestoreEmptyDetail: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 108))
                .foregroundColor(Color.App.accent.color(for: colorScheme).opacity(0.7))

            Text("Detail_Restore_Placeholder_Select_Backup")
                .font(DesignConstants.Typography.headline)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
