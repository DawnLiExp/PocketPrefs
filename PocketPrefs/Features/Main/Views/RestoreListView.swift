//
//  RestoreListView.swift
//  PocketPrefs
//
//  Restore backup list with event-driven updates
//

import SwiftUI

struct RestoreListView: View {
    @ObservedObject var coordinator: MainCoordinator
    @Binding var selectedApp: AppConfig?
    
    @StateObject private var viewModel: RestoreListViewModel
    @State private var selectedBackupApp: BackupAppInfo?
    @Environment(\.colorScheme) var colorScheme
    
    init(coordinator: MainCoordinator, selectedApp: Binding<AppConfig?>) {
        self.coordinator = coordinator
        self._selectedApp = selectedApp
        self._viewModel = StateObject(wrappedValue: RestoreListViewModel(coordinator: coordinator))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            RestoreListHeader(
                coordinator: coordinator,
                searchText: $viewModel.searchText,
                viewModel: viewModel,
            )
            .padding(.bottom, 6)
            
            // Only the scrollable list content needs to be non-draggable
            NonDraggableView {
                RestoreListContent(
                    coordinator: coordinator,
                    selectedBackupApp: $selectedBackupApp,
                    viewModel: viewModel,
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.onAppear()
        }
        .onChange(of: viewModel.searchText) { _, newValue in
            viewModel.handleSearchChange(newValue)
        }
        .task {
            for await event in SettingsEventPublisher.shared.subscribe() {
                if case .didClose = event {
                    viewModel.onSettingsClose()
                }
            }
        }
    }
}

// MARK: - Header Components

struct RestoreListHeader: View {
    @ObservedObject var coordinator: MainCoordinator
    @Binding var searchText: String
    @ObservedObject var viewModel: RestoreListViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(NSLocalizedString("Restore_Backup_Title", comment: ""))
                .font(DesignConstants.Typography.title)
                .foregroundColor(Color.App.primary.color(for: colorScheme))
            
            HStack(spacing: 13) {
                CustomBackupPicker(coordinator: coordinator)
                
                RefreshButton(
                    isRefreshing: $viewModel.isRefreshing,
                    action: {
                        Task { @MainActor in
                            await viewModel.refreshBackups()
                        }
                    },
                )
            }
            
            if viewModel.selectedBackup != nil {
                SearchFieldView(searchText: $searchText)
                
                HStack {
                    Toggle(isOn: Binding(
                        get: { viewModel.cachedAllSelected },
                        set: { _ in viewModel.toggleSelectAll() },
                    )) {
                        Text(NSLocalizedString("Select_All", comment: ""))
                            .font(DesignConstants.Typography.body)
                    }
                    .toggleStyle(CustomCheckboxToggleStyle())
                    
                    Spacer()
                    
                    Text(String(
                        format: NSLocalizedString("Selected_Count", comment: ""),
                        viewModel.cachedSelectedCount,
                        viewModel.cachedTotalCount,
                    ))
                    .font(DesignConstants.Typography.caption)
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, 20)
        .padding(.bottom, 11)
        .background(Color.App.contentAreaBackground.color(for: colorScheme))
    }
}

struct SearchFieldView: View {
    @Binding var searchText: String
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
                .font(.system(size: 14))
            
            TextField(NSLocalizedString("Search_Placeholder", comment: ""), text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isFocused)
                .font(DesignConstants.Typography.body)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.App.secondary.color(for: colorScheme))
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                .fill(
                    (Color.App.tertiaryBackground.color(for: colorScheme)).opacity(0.7),
                ),
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                .stroke(
                    Color.App.lightSeparator.color(for: colorScheme).opacity(0.7),
                    lineWidth: 1.0,
                ),
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

struct RefreshButton: View {
    @Binding var isRefreshing: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Color.clear
                    .contentShape(RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius))
                
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.App.primary.color(for: colorScheme))
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(
                        isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default,
                        value: isRefreshing,
                    )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 32, height: 32)
        .background(
            Color.App.contentAreaBackground.color(for: colorScheme),
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius))
        .disabled(isRefreshing)
    }
}

// MARK: - Content Area

struct RestoreListContent: View {
    @ObservedObject var coordinator: MainCoordinator
    @Binding var selectedBackupApp: BackupAppInfo?
    @ObservedObject var viewModel: RestoreListViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if viewModel.selectedBackup != nil, !viewModel.availableBackups.isEmpty {
                if viewModel.filteredApps.isEmpty, !viewModel.searchText.isEmpty {
                    SearchEmptyState(searchText: viewModel.searchText)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.filteredApps, id: \.id) { app in
                                RestoreAppItem(
                                    app: app,
                                    isSelected: selectedBackupApp?.id == app.id,
                                    coordinator: coordinator,
                                    viewModel: viewModel,
                                ) {
                                    withAnimation(DesignConstants.Animation.quick) {
                                        selectedBackupApp = app
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 15)
                        .padding(.bottom, 15)
                        .padding(.top, 3)
                    }
                }
            } else {
                RestoreEmptyState()
            }
        }
    }
}

// MARK: - Empty States

struct SearchEmptyState: View {
    let searchText: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor((Color.App.secondary.color(for: colorScheme)).opacity(0.5))
            Text(String(format: NSLocalizedString("Search_No_Results", comment: ""), searchText))
                .font(DesignConstants.Typography.headline)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
            Text(NSLocalizedString("Search_Try_Different_Keyword", comment: ""))
                .font(DesignConstants.Typography.body)
                .foregroundColor((Color.App.secondary.color(for: colorScheme)).opacity(0.8))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RestoreEmptyState: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "archivebox")
                .font(.system(size: 48))
                .foregroundColor((Color.App.secondary.color(for: colorScheme)).opacity(0.5))
            Text(NSLocalizedString("Restore_Empty_State_No_Backups", comment: ""))
                .font(DesignConstants.Typography.headline)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
            Text(NSLocalizedString("Restore_Empty_State_Create_Backup_Prompt", comment: ""))
                .font(DesignConstants.Typography.body)
                .foregroundColor((Color.App.secondary.color(for: colorScheme)).opacity(0.8))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - List Item

struct RestoreAppItem: View {
    let app: BackupAppInfo
    let isSelected: Bool
    @ObservedObject var coordinator: MainCoordinator
    @ObservedObject var viewModel: RestoreListViewModel
    let onTap: () -> Void
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    
    private var isChecked: Bool {
        guard let backup = viewModel.selectedBackup else { return false }
        return backup.apps.first(where: { $0.id == app.id })?.isSelected ?? false
    }
    
    var body: some View {
        HStack(spacing: 5) {
            Toggle("", isOn: Binding(
                get: { isChecked },
                set: { _ in viewModel.toggleSelection(for: app) },
            ))
            .toggleStyle(CustomCheckboxToggleStyle())
            
            Group {
                let icon = coordinator.getIcon(for: app)
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(app.name)
                        .font(DesignConstants.Typography.headline)
                        .foregroundColor(Color.App.primary.color(for: colorScheme))
                    
                    if !app.isCurrentlyInstalled {
                        StatusBadge(
                            text: NSLocalizedString("Restore_App_Status_Not_Installed", comment: ""),
                            color: Color.App.warning.color(for: colorScheme),
                            style: .compact,
                        )
                    } else {
                        StatusBadge(
                            text: NSLocalizedString("Restore_App_Status_Installed", comment: ""),
                            color: Color.App.success.color(for: colorScheme),
                            style: .compact,
                        )
                    }
                }
                
                Text(String(format: NSLocalizedString("Restore_App_Config_Files_Count", comment: ""), app.configPaths.count))
                    .font(DesignConstants.Typography.caption)
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
                .opacity(isHovered ? 0.6 : 0)
        }
        .padding(11)
        .cardEffect(isSelected: isSelected)
        .onTapGesture(perform: onTap)
        .onHover { hovering in
            withAnimation(DesignConstants.Animation.quick) {
                isHovered = hovering
            }
        }
    }
}
