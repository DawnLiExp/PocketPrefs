//
//  BackupManagementView.swift
//  PocketPrefs
//
//  Two-column backup management UI: left = backup list, right = app detail.
//

import SwiftUI

// MARK: - BackupManagementView

struct BackupManagementView: View {
    @Bindable var viewModel: BackupManagementViewModel

    var body: some View {
        HStack(spacing: 0) {
            BackupListColumn(viewModel: viewModel)
                .frame(width: 280)

            Divider()

            BackupDetailColumn(viewModel: viewModel)
                .frame(maxWidth: .infinity)
        }
        .task {
            await viewModel.loadBackups()
        }
        .bindAlert($viewModel.pendingAlert)
    }
}

// MARK: - Left Column

struct BackupListColumn: View {
    @Bindable var viewModel: BackupManagementViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(viewModel.backups) { backup in
                        BackupListRow(backup: backup, viewModel: viewModel)
                    }
                }
                .padding(10)
            }

            Divider()

            BackupListToolbar(viewModel: viewModel)
                .frame(height: 44)
        }
        .background(Color.App.background.color(for: colorScheme))
    }
}

// MARK: - Backup List Row

struct BackupListRow: View {
    let backup: BackupInfo
    @Bindable var viewModel: BackupManagementViewModel
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Toggle(isOn: Binding(
                get: { viewModel.selectedBackupIds.contains(backup.id) },
                set: { _ in viewModel.toggleBackupSelection(backup.id) }
            )) { EmptyView() }
                .toggleStyle(CustomCheckboxToggleStyle())

            VStack(alignment: .leading, spacing: 3) {
                Text(backup.formattedName)
                    .font(DesignConstants.Typography.headline)
                    .foregroundColor(Color.App.primary.color(for: colorScheme))

                HStack(spacing: 4) {
                    Text(String(
                        localized: "Backup_Management_Apps_Count",
                        defaultValue: "\(backup.apps.count) apps"
                    ))
                    Text(verbatim: "·")
                    Text(viewModel.backupSizeCache[backup.path] ?? "—")
                }
                .font(DesignConstants.Typography.caption)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { viewModel.selectDetailBackup(backup) }

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
                .opacity(viewModel.detailBackup?.id == backup.id ? 1 : (isHovered ? 0.5 : 0))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .cardEffect(isSelected: viewModel.detailBackup?.id == backup.id)
        .onHover { hovering in
            withAnimation(DesignConstants.Animation.quick) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Backup List Toolbar

struct BackupListToolbar: View {
    @Bindable var viewModel: BackupManagementViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.isLoading)

            Spacer()

            if viewModel.selectedCount > 0 {
                Text(String(
                    localized: "Backup_Management_Selected_Count",
                    defaultValue: "\(viewModel.selectedCount) selected"
                ))
                .font(DesignConstants.Typography.caption)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }

            Button(String(localized: "Backup_Management_Merge_Button")) {
                viewModel.performMerge()
            }
            .buttonStyle(ToolbarButtonStyle(isDestructive: false))
            .disabled(!viewModel.canMerge || viewModel.isMerging)

            Button(role: .destructive) {
                viewModel.batchDeleteSelectedBackups()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(ToolbarButtonStyle(isDestructive: true))
            .disabled(!viewModel.canBatchDelete || viewModel.isLoading)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.App.tertiaryBackground.color(for: colorScheme).opacity(0.3))
    }
}

// MARK: - Right Column

struct BackupDetailColumn: View {
    @Bindable var viewModel: BackupManagementViewModel
    @Environment(\.colorScheme) var colorScheme

    // Single-row highlight state (for Finder button), independent from multi-select checkboxes.
    @State private var selectedRowId: String?

    var body: some View {
        Group {
            if (viewModel.isLoading && viewModel.backups.isEmpty) || viewModel.isMerging {
                VStack(spacing: 12) {
                    SwiftUI.ProgressView()
                    Text(
                        viewModel.isMerging
                            ? String(localized: "Backup_Management_Merging")
                            : String(localized: "Backup_Management_Loading")
                    )
                    .font(DesignConstants.Typography.body)
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if let backup = viewModel.detailBackup {
                VStack(spacing: 0) {
                    BackupDetailHeader(
                        backup: backup,
                        totalSize: viewModel.backupSizeCache[backup.path]
                    )
                    .padding(16)

                    Divider()

                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(backup.apps) { app in
                                BackupAppRow(
                                    app: app,
                                    sizeString: viewModel.appSizeCache[app.path] ?? "—",
                                    isChecked: viewModel.selectedDetailAppIds.contains(app.id),
                                    isRowSelected: selectedRowId == app.id,
                                    onToggleCheck: {
                                        viewModel.toggleDetailAppSelection(app.id)
                                    },
                                    onSelectRow: {
                                        withAnimation(DesignConstants.Animation.quick) {
                                            selectedRowId = app.id
                                        }
                                    }
                                )
                            }
                        }
                        .padding(12)
                    }

                    Divider()

                    BackupDetailToolbar(
                        selectedCount: viewModel.selectedDetailCount,
                        isLoading: viewModel.isLoading,
                        onDelete: { viewModel.deleteSelectedDetailApps() },
                        onClearSelection: { viewModel.clearDetailSelection() }
                    )
                    .frame(height: 44)
                }
                // Reset single-row highlight whenever the detail backup switches.
                .onChange(of: viewModel.detailBackup?.id) { _, _ in
                    selectedRowId = nil
                }

            } else {
                BackupDetailEmptyState()
            }
        }
    }
}

// MARK: - Detail Header

struct BackupDetailHeader: View {
    let backup: BackupInfo
    let totalSize: String?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "externaldrive.badge.timemachine")
                .font(.system(size: 24))
                .foregroundColor(Color.App.accent.color(for: colorScheme))

            VStack(alignment: .leading, spacing: 4) {
                Text(backup.formattedName)
                    .font(DesignConstants.Typography.title)

                HStack(spacing: 6) {
                    Text(String(
                        localized: "Backup_Management_Apps_Count",
                        defaultValue: "\(backup.apps.count) apps"
                    ))
                    Text(verbatim: "·")
                    Text(totalSize ?? "—")
                }
                .font(DesignConstants.Typography.caption)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }

            Spacer()
        }
    }
}

// MARK: - Detail Toolbar (right column)

struct BackupDetailToolbar: View {
    let selectedCount: Int
    let isLoading: Bool
    let onDelete: () -> Void
    let onClearSelection: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            // "Deselect All" only visible when items are checked — provides bulk-cancel UX.
            if selectedCount > 0 {
                Button(action: onClearSelection) {
                    Text(String(localized: "Common_Deselect_All", defaultValue: "Deselect All"))
                        .font(DesignConstants.Typography.caption)
                        .foregroundColor(Color.App.secondary.color(for: colorScheme))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Button text uses monospacedDigit to prevent width jitter on count change.
            // No animation applied to this HStack; button state transitions are instant.
            Button(
                String(localized: "Settings_Delete_Selected", defaultValue: "Delete \(selectedCount) Selected"),
                role: .destructive,
                action: onDelete
            )
            .font(DesignConstants.Typography.headline.monospacedDigit())
            .buttonStyle(ToolbarButtonStyle(isDestructive: true))
            .disabled(selectedCount == 0 || isLoading)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.App.tertiaryBackground.color(for: colorScheme).opacity(0.3))
    }
}

// MARK: - App Row

struct BackupAppRow: View {
    let app: BackupAppInfo
    let sizeString: String
    /// Whether the checkbox is ticked (multi-select for batch delete).
    let isChecked: Bool
    /// Whether this row is the single-highlighted row (for Finder button).
    let isRowSelected: Bool
    let onToggleCheck: () -> Void
    let onSelectRow: () -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            // Checkbox tap is handled by Toggle internally and does NOT propagate
            // to the row's onTapGesture below.
            Toggle(isOn: Binding(
                get: { isChecked },
                set: { _ in onToggleCheck() }
            )) { EmptyView() }
                .toggleStyle(CustomCheckboxToggleStyle())

            Image(nsImage: IconService.shared.getIcon(for: app.bundleId, category: app.category))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(DesignConstants.Typography.headline)
                    .foregroundColor(Color.App.primary.color(for: colorScheme))
                Text(sizeString)
                    .font(DesignConstants.Typography.caption)
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }

            Spacer()

            if isRowSelected {
                Button(action: {
                    NSWorkspace.shared.selectFile(app.path, inFileViewerRootedAtPath: "")
                }) {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 16))
                        .foregroundColor(Color.App.secondary.color(for: colorScheme))
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
                    .opacity(isHovered ? 0.5 : 0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        // cardEffect follows single-row highlight, not checkbox state.
        .cardEffect(isSelected: isRowSelected)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelectRow)
        .onHover { hovering in
            withAnimation(DesignConstants.Animation.quick) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Empty State

struct BackupDetailEmptyState: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive")
                .font(.system(size: 48))
                .foregroundColor(Color.App.secondary.color(for: colorScheme).opacity(0.5))
            Text(String(localized: "Backup_Management_Empty_State"))
                .font(DesignConstants.Typography.headline)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
