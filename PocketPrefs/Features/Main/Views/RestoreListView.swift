//
//  RestoreListView.swift
//  PocketPrefs
//
//  Restore backup list with event-driven updates
//

import SwiftUI

struct RestoreListView: View {
    @Environment(MainCoordinator.self) private var coordinator

    var body: some View {
        RestoreListContent(coordinator: coordinator)
    }
}

private struct RestoreListContent: View {
    @State private var viewModel: RestoreListViewModel

    init(coordinator: MainCoordinator) {
        self._viewModel = State(wrappedValue: RestoreListViewModel(coordinator: coordinator))
    }

    var body: some View {
        VStack(spacing: 0) {
            RestoreListHeader(
                searchText: $viewModel.searchText,
                viewModel: viewModel,
                cachedSelectedCount: viewModel.cachedSelectedCount,
                cachedTotalCount: viewModel.cachedTotalCount,
            )
            .padding(.bottom, 6)

            // Only the scrollable list content needs to be non-draggable
            NonDraggableView {
                RestoreListScrollArea(
                    viewModel: viewModel,
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.onAppear()
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
    @Binding var searchText: String
    @Bindable var viewModel: RestoreListViewModel
    let cachedSelectedCount: Int
    let cachedTotalCount: Int
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Restore_Backup_Title")
                .font(DesignConstants.Typography.title)
                .foregroundColor(Color.App.primary.color(for: colorScheme))

            HStack(spacing: 13) {
                CustomBackupPicker()

                RefreshButton(
                    isRefreshing: viewModel.isRefreshing,
                    isEnabled: !viewModel.isRefreshing,
                    action: {
                        Task { @MainActor in
                            await viewModel.refreshBackups()
                        }
                    },
                )
            }

            if viewModel.selectedBackup != nil {
                SearchFieldView(searchText: $searchText, viewModel: viewModel)

                HStack {
                    Toggle(isOn: Binding(
                        get: { viewModel.cachedAllSelected },
                        set: { _ in viewModel.toggleSelectAll() },
                    )) {
                        Text("Select_All")
                            .font(DesignConstants.Typography.body)
                    }
                    .toggleStyle(CustomCheckboxToggleStyle())
                    .disabled(viewModel.cachedTotalCount == 0)

                    Spacer()

                    Text(String(localized: "Selected_Count", defaultValue: "Selected \(cachedSelectedCount) / \(cachedTotalCount)"))
                        .font(DesignConstants.Typography.caption)
                        .foregroundColor(Color.App.secondary.color(for: colorScheme))
                }

                if !searchText.isEmpty {
                    Text(String(localized: "Restore_Overall_Selected_Count", defaultValue: "Total selected: \(viewModel.cachedOverallSelectedCount)"))
                        .font(DesignConstants.Typography.caption)
                        .foregroundStyle(Color.App.primary.color(for: colorScheme))
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
    var viewModel: RestoreListViewModel
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
                .font(.system(size: 14))
                .padding(.leading, 12)
                .padding(.trailing, 8)

            TextField("Search_Placeholder", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isFocused)
                .font(DesignConstants.Typography.body)

            Spacer(minLength: 8)

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.App.secondary.color(for: colorScheme))
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 8)
            }

            // MARK: - Modified Menu

            Menu {
                ForEach(viewModel.supportedSortOptions, id: \.self) { option in
                    Button {
                        viewModel.setSortOption(option)
                    } label: {
                        HStack {
                            Image(systemName: viewModel.currentSortOption == option ? "checkmark.circle" : "circle")
                                .font(.system(size: 10))
                            Text(option.displayName)
                        }
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
                    .font(.system(size: 14))
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .menuIndicator(.hidden)
            .menuStyle(.borderlessButton)
            .fixedSize()
            .padding(.trailing, 12)
        }
        .frame(height: 36)
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

    }
}

// MARK: - Content Area

struct RestoreListScrollArea: View {
    var viewModel: RestoreListViewModel
    @Environment(MainCoordinator.self) private var coordinator
    @FocusState private var focusedRowID: String?

    var body: some View {
        Group {
            if viewModel.selectedBackup != nil, !viewModel.availableBackups.isEmpty {
                if viewModel.filteredApps.isEmpty, !viewModel.searchText.isEmpty {
                    SearchEmptyState(searchText: viewModel.searchText)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(viewModel.filteredApps, id: \.id) { app in
                                    RestoreAppItem(
                                        app: app,
                                        viewModel: viewModel,
                                        focus: $focusedRowID,
                                    )
                                }
                            }
                            .padding(.horizontal, 15)
                            .padding(.bottom, 15)
                            .padding(.top, 3)
                        }
                        .keyboardListNavigation(ids: viewModel.filteredApps.map(\.id), focus: $focusedRowID)
                        .onChange(of: focusedRowID) { _, id in
                            if let id { proxy.scrollTo(id) }
                        }
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
            Text(String(localized: "Search_No_Results", defaultValue: "No apps found for \"\(searchText)\""))
                .font(DesignConstants.Typography.headline)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
            Text("Search_Try_Different_Keyword")
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
            Text("Restore_Empty_State_No_Backups")
                .font(DesignConstants.Typography.headline)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
            Text("Restore_Empty_State_Create_Backup_Prompt")
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
    var viewModel: RestoreListViewModel
    let focus: FocusState<String?>.Binding
    @Environment(\.colorScheme) var colorScheme
    @Environment(MainCoordinator.self) private var coordinator

    private var isChecked: Bool {
        app.isSelected
    }

    var body: some View {
        Toggle(
            isOn: Binding(
                get: { isChecked },
                set: { _ in viewModel.toggleSelection(for: app) },
            )
        ) {
            HStack(spacing: 5) {
                Group {
                    let icon = coordinator.getIcon(for: app)
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name)
                        .font(DesignConstants.Typography.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(app.name)
                    HStack(spacing: 6) {
                        Text(String(localized: "Restore_App_Config_Files_Count", defaultValue: "\(app.configPaths.count) config files"))
                            .font(DesignConstants.Typography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        StatusBadge(
                            text: app.isCurrentlyInstalled
                                ? String(localized: "Restore_App_Status_Installed") : String(localized: "Restore_App_Status_Not_Installed"),
                            color: app.isCurrentlyInstalled ? Color.App.success.color(for: colorScheme) : Color.App.warning.color(for: colorScheme),
                            style: .compact)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .toggleStyle(CustomCheckboxToggleStyle())
        .accessibilityLabel(Text(app.name))
        .focused(focus, equals: app.id)
        .focusEffectDisabled()
        .padding(11)
        .cardEffect(isSelected: isChecked)
        .rowFocusOutline(focus.wrappedValue == app.id)
    }
}