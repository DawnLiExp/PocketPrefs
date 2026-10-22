//
//  AppListView.swift
//  PocketPrefs
//
//  Backup app list with incremental mode support
//

import SwiftUI

struct AppListView: View {
    @Binding var selectedAppID: String?
    let currentMode: MainView.AppMode
    @Environment(MainCoordinator.self) private var coordinator
    @Environment(MainViewModel.self) private var mainViewModel

    var body: some View {
        AppListContent(
            coordinator: coordinator,
            mainViewModel: mainViewModel,
            selectedAppID: $selectedAppID,
            currentMode: currentMode,
        )
    }
}

private struct AppListContent: View {
    let mainViewModel: MainViewModel
    @Binding var selectedAppID: String?
    let currentMode: MainView.AppMode
    @State private var viewModel: AppListViewModel
    @State private var appPendingDeletion: AppConfig?
    @FocusState private var focusedRowID: String?

    init(
        coordinator: MainCoordinator,
        mainViewModel: MainViewModel,
        selectedAppID: Binding<String?>,
        currentMode: MainView.AppMode,
    ) {
        self.mainViewModel = mainViewModel
        self._selectedAppID = selectedAppID
        self.currentMode = currentMode
        self._viewModel = State(wrappedValue: AppListViewModel(coordinator: coordinator))
    }

    var body: some View {
        VStack(spacing: 0) {
            AppListHeader(
                searchText: $viewModel.searchText,
                mainViewModel: mainViewModel,
                viewModel: viewModel,
                selectedCount: viewModel.cachedSelectedCount,
                totalCount: viewModel.apps.count,
            )

            // Only the scrollable list content needs to be non-draggable
            NonDraggableView {
                if viewModel.filteredApps.isEmpty, !viewModel.searchText.isEmpty {
                    BackupSearchEmptyState(searchText: viewModel.searchText)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(viewModel.filteredApps) { app in
                                    AppListItem(
                                        app: app,
                                        isSelected: selectedAppID == app.id,
                                        viewModel: viewModel,
                                        currentMode: currentMode,
                                        onDelete: { appPendingDeletion = app },
                                        focus: $focusedRowID,
                                    ) {
                                        selectedAppID = app.id
                                    }
                                }
                            }
                            .padding(.horizontal, 15)
                            .padding(.bottom, 15)
                            .padding(.top, 3)
                        }
                        .keyboardListNavigation(ids: viewModel.filteredApps.map(\.id), focus: $focusedRowID) { selectedAppID = $0 }
                        .onChange(of: focusedRowID) { _, id in
                            if let id { proxy.scrollTo(id) }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.onAppear()
        }
        .alert(
            deleteAlertTitle,
            isPresented: Binding(
                get: { appPendingDeletion != nil },
                set: { if !$0 { appPendingDeletion = nil } }
            ),
            presenting: appPendingDeletion,
        ) { app in
            Button(
                app.isUserAdded
                    ? String(localized: "Common_Delete")
                    : String(localized: "AppList_Delete_Preset_Confirm", defaultValue: "Remove"),
                role: .destructive,
            ) {
                viewModel.deleteApp(app)
                if selectedAppID == app.id { selectedAppID = nil }
                appPendingDeletion = nil
            }
            Button(String(localized: "Common_Cancel"), role: .cancel) {
                appPendingDeletion = nil
            }
        } message: { app in
            Text(
                app.isUserAdded
                    ? String(
                        localized: "AppList_Delete_Custom_Alert_Message",
                        defaultValue: "This will permanently delete this app configuration. This action cannot be undone.")
                    : String(
                        localized: "AppList_Delete_Preset_Alert_Message",
                        defaultValue: "\(app.name) is a built-in preset. After removal, you can re-add it manually in Settings.")
            )
        }
    }

    // MARK: - Private Helpers

    private var deleteAlertTitle: String {
        guard let app = appPendingDeletion else { return "" }
        return app.isUserAdded
            ? String(localized: "AppList_Delete_Custom_Alert_Title", defaultValue: "Delete \"\(app.name)\"?")
            : String(localized: "AppList_Delete_Preset_Alert_Title", defaultValue: "Remove \"\(app.name)\"?")
    }
}

// MARK: - Header Components

struct AppListHeader: View {
    @Binding var searchText: String
    var mainViewModel: MainViewModel
    @Bindable var viewModel: AppListViewModel
    let selectedCount: Int
    let totalCount: Int
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isSearchFocused: Bool
    @Environment(MainCoordinator.self) private var coordinator

    private var hasAvailableBackups: Bool {
        !coordinator.currentBackups.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            // Search field with sort button
            HStack(spacing: 0) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
                    .font(.system(size: 14))
                    .padding(.leading, 12)
                    .padding(.trailing, 8)

                TextField(
                    "Search_Placeholder",
                    text: $searchText,
                )
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isSearchFocused)
                .font(DesignConstants.Typography.body)

                Spacer(minLength: 8)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.App.secondary.color(for: colorScheme))
                            .font(.system(size: 14))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .keyboardFocusOutline()
                    .accessibilityLabel(Text("Accessibility_Clear_Search"))
                    .help("Accessibility_Clear_Search")
                    .padding(.trailing, 8)
                }

                // MARK: - Sort Menu

                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
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
                .accessibilityLabel(Text("Accessibility_Sort_Apps"))
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

            ViewThatFits(in: .horizontal) {
                HStack {
                    selectionControls.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 8)
                    selectionCount
                }
                VStack(alignment: .leading, spacing: 8) {
                    selectionControls
                    selectionCount.frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            if mainViewModel.isIncrementalMode, hasAvailableBackups {
                IncrementalBaseSelector()
                    .padding(.top, 0)
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, 11)
        .padding(.bottom, 15)
        .background(Color.App.contentAreaBackground.color(for: colorScheme))
    }
    private var selectionControls: some View {
        HStack(spacing: 16) {
            Toggle(isOn: Binding(get: { viewModel.cachedAllSelected }, set: { _ in viewModel.toggleSelectAll() })) {
                Text("Select_All").font(DesignConstants.Typography.body)
            }
            .toggleStyle(CustomCheckboxToggleStyle())
            IncrementalModeToggle(mainViewModel: mainViewModel, hasAvailableBackups: hasAvailableBackups)
        }
    }

    private var selectionCount: some View {
        Text(String(localized: "Selected_Count", defaultValue: "Selected \(selectedCount) / \(totalCount)"))
            .font(DesignConstants.Typography.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: true, vertical: false)
    }

}

struct IncrementalModeToggle: View {
    @Bindable var mainViewModel: MainViewModel
    let hasAvailableBackups: Bool
    @State private var showingHelp = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            Toggle(isOn: $mainViewModel.isIncrementalMode) {
                Text("Incremental_Mode")
                    .font(DesignConstants.Typography.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .toggleStyle(CustomCheckboxToggleStyle())
            .disabled(!hasAvailableBackups)

            Button(action: { showingHelp.toggle() }) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 14))
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }
            .buttonStyle(PlainButtonStyle())
            .keyboardFocusOutline()
            .accessibilityLabel(Text("Accessibility_Incremental_Help"))
            .popover(isPresented: $showingHelp, arrowEdge: .bottom) {
                IncrementalModeHelpPopover()
            }
        }
    }
}

struct IncrementalModeHelpPopover: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text("Incremental_Mode_Help_Description")
            .font(DesignConstants.Typography.body)
            .foregroundColor(Color.App.secondary.color(for: colorScheme))
            .multilineTextAlignment(.leading)
            .padding(12)
            .frame(width: 260, alignment: .leading)
    }
}

struct IncrementalBaseSelector: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var localRefreshing = false
    @Environment(MainCoordinator.self) private var coordinator
    @Environment(MainViewModel.self) private var mainViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Select_Base_Backup_Label")
                .font(DesignConstants.Typography.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                BackupSelectionMenu(
                    backups: coordinator.currentBackups, selectedBackup: mainViewModel.incrementalBaseBackup,
                    label: "Select_Base_Backup_Label", onSelect: mainViewModel.selectIncrementalBase)
                RefreshButton(isRefreshing: localRefreshing, isEnabled: !localRefreshing) {
                    Task { @MainActor in await refreshBackups() }
                }
            }
        }
    }

    @MainActor
    private func refreshBackups() async {
        localRefreshing = true
        try? await Task.sleep(nanoseconds: 200_000_000)
        await coordinator.scanBackups()
        localRefreshing = false
    }
}

// MARK: - Empty State

struct BackupSearchEmptyState: View {
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

// MARK: - List Item

struct AppListItem: View {
    let app: AppConfig
    let isSelected: Bool
    let viewModel: AppListViewModel
    let currentMode: MainView.AppMode
    let onDelete: () -> Void
    let focus: FocusState<String?>.Binding
    let onTap: () -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(MainCoordinator.self) private var coordinator

    private var isChecked: Bool {
        app.isSelected
    }

    var body: some View {
        HStack(spacing: 5) {
            Toggle(
                isOn: Binding(
                    get: { isChecked },
                    set: { _ in viewModel.toggleSelection(for: app) },
                )
            ) {
                Text(app.name)
            }
            .toggleStyle(CustomCheckboxToggleStyle())
            .labelsHidden()
            .accessibilityLabel(Text(app.name))
            .disabled(currentMode == .backup ? !app.isInstalled : false)

            Button(action: onTap) {
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
                            .foregroundColor(
                                app.isInstalled || currentMode == .restore
                                    ? Color.App.primary.color(for: colorScheme) : Color.App.secondary.color(for: colorScheme)
                            )
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .help(app.name)
                        HStack(spacing: 6) {
                            Text(String(localized: "AppList_App_Config_Paths_Count", defaultValue: "\(app.configPaths.count) config paths"))
                                .font(DesignConstants.Typography.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            if currentMode == .backup, !app.isInstalled {
                                StatusBadge(
                                    text: String(localized: "AppList_App_Status_Not_Installed", defaultValue: "Not Installed"),
                                    color: Color.App.notInstalled.color(for: colorScheme), style: .compact)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(Color.App.secondary.color(for: colorScheme))
                        .opacity(isSelected ? 1 : (isHovered ? 0.5 : 0))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focused(focus, equals: app.id)
            .focusEffectDisabled()
            .accessibilityLabel(Text(String(localized: "Accessibility_App_Details", defaultValue: "View details for \(app.name)")))
        }
        .padding(11)
        .cardEffect(isSelected: isSelected)
        .rowFocusOutline(focus.wrappedValue == app.id)
        .onHover { hovering in
            withAnimation(DesignConstants.Animation.quick) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label(
                    String(localized: "AppList_Context_Menu_Delete", defaultValue: "Delete"),
                    systemImage: "trash",
                )
            }
        }
    }
}