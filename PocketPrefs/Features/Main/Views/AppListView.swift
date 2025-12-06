//
//  AppListView.swift
//  PocketPrefs
//
//  Backup app list with incremental mode support
//

import SwiftUI

struct AppListView: View {
    @ObservedObject var coordinator: MainCoordinator
    @ObservedObject var mainViewModel: MainViewModel
    @Binding var selectedApp: AppConfig?
    let currentMode: MainView.AppMode
    
    @StateObject private var viewModel: AppListViewModel
    @Environment(\.colorScheme) var colorScheme
    
    init(
        coordinator: MainCoordinator,
        mainViewModel: MainViewModel,
        selectedApp: Binding<AppConfig?>,
        currentMode: MainView.AppMode,
    ) {
        self.coordinator = coordinator
        self.mainViewModel = mainViewModel
        self._selectedApp = selectedApp
        self.currentMode = currentMode
        self._viewModel = StateObject(wrappedValue: AppListViewModel(coordinator: coordinator))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            AppListHeader(
                searchText: $viewModel.searchText,
                coordinator: coordinator,
                mainViewModel: mainViewModel,
                viewModel: viewModel,
            )
            
            // Only the scrollable list content needs to be non-draggable
            NonDraggableView {
                if viewModel.filteredApps.isEmpty, !viewModel.searchText.isEmpty {
                    BackupSearchEmptyState(searchText: viewModel.searchText)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.filteredApps) { app in
                                AppListItem(
                                    app: app,
                                    isSelected: selectedApp?.id == app.id,
                                    coordinator: coordinator,
                                    viewModel: viewModel,
                                    currentMode: currentMode,
                                ) {
                                    withAnimation(DesignConstants.Animation.quick) {
                                        selectedApp = app
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 15)
                        .padding(.bottom, 15)
                        .padding(.top, 3)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.onAppear()
        }
        .onChange(of: viewModel.searchText) { _, newValue in
            viewModel.handleSearchChange(newValue)
        }
    }
}

// MARK: - Header Components

struct AppListHeader: View {
    @Binding var searchText: String
    @ObservedObject var coordinator: MainCoordinator
    @ObservedObject var mainViewModel: MainViewModel
    @ObservedObject var viewModel: AppListViewModel
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isSearchFocused: Bool
    
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
                    NSLocalizedString("Search_Placeholder", comment: ""),
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
                    .padding(.trailing, 8)
                }
                    
                // MARK: - Modified Menu

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
            .animation(.easeInOut(duration: 0.15), value: isSearchFocused)
            
            HStack(spacing: 16) {
                Toggle(isOn: Binding(
                    get: { viewModel.cachedAllSelected },
                    set: { _ in viewModel.toggleSelectAll() },
                )) {
                    Text(NSLocalizedString("Select_All", comment: ""))
                        .font(DesignConstants.Typography.body)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .toggleStyle(CustomCheckboxToggleStyle())
                
                IncrementalModeToggle(
                    mainViewModel: mainViewModel,
                    hasAvailableBackups: hasAvailableBackups,
                )
                
                Spacer()
                
                Text(String(
                    format: NSLocalizedString("Selected_Count", comment: ""),
                    viewModel.apps.count(where: { $0.isSelected }),
                    viewModel.apps.count,
                ))
                .font(DesignConstants.Typography.caption)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.bottom, mainViewModel.isIncrementalMode && hasAvailableBackups ? 0 : 0)
            
            if mainViewModel.isIncrementalMode, hasAvailableBackups {
                IncrementalBaseSelector(
                    mainViewModel: mainViewModel,
                    coordinator: coordinator,
                    isRefreshing: .constant(false),
                )
                .padding(.top, 0)
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, 11)
        .padding(.bottom, 15)
        .background(Color.App.contentAreaBackground.color(for: colorScheme))
    }
}

struct IncrementalModeToggle: View {
    @ObservedObject var mainViewModel: MainViewModel
    let hasAvailableBackups: Bool
    @State private var showingHelp = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 6) {
            Toggle(isOn: Binding(
                get: { mainViewModel.isIncrementalMode },
                set: { newValue in
                    if hasAvailableBackups {
                        mainViewModel.isIncrementalMode = newValue
                    }
                },
            )) {
                Text(NSLocalizedString("Incremental_Mode", comment: ""))
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
            .popover(isPresented: $showingHelp, arrowEdge: .bottom) {
                IncrementalModeHelpPopover()
            }
        }
    }
}

struct IncrementalModeHelpPopover: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Text(NSLocalizedString("Incremental_Mode_Help_Description", comment: ""))
            .font(DesignConstants.Typography.body)
            .foregroundColor(Color.App.secondary.color(for: colorScheme))
            .multilineTextAlignment(.leading)
            .padding(12)
            .frame(width: 260, alignment: .leading)
    }
}

struct IncrementalBaseSelector: View {
    @ObservedObject var mainViewModel: MainViewModel
    @ObservedObject var coordinator: MainCoordinator
    @Binding var isRefreshing: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var localRefreshing = false
    
    var body: some View {
        HStack(spacing: 8) {
            Text(NSLocalizedString("Select_Base_Backup_Label", comment: ""))
                .font(DesignConstants.Typography.body)
                .foregroundColor(Color.App.primary.color(for: colorScheme))
            
            Menu {
                ForEach(coordinator.currentBackups) { backup in
                    Button {
                        mainViewModel.selectIncrementalBase(backup)
                    } label: {
                        Text(backup.formattedName)
                    }
                }
            } label: {
                Text(mainViewModel.incrementalBaseBackup?.formattedName ?? "")
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
            
            Button(action: {
                Task { @MainActor in
                    await refreshBackups()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.App.primary.color(for: colorScheme))
                    .rotationEffect(.degrees(localRefreshing ? 360 : 0))
                    .animation(
                        localRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default,
                        value: localRefreshing,
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 32, height: 32)
            .background(
                Color.App.contentAreaBackground.color(for: colorScheme),
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius))
            .disabled(localRefreshing)
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

// MARK: - List Item

struct AppListItem: View {
    let app: AppConfig
    let isSelected: Bool
    let coordinator: MainCoordinator
    let viewModel: AppListViewModel
    let currentMode: MainView.AppMode
    let onTap: () -> Void
    
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    
    private var isChecked: Bool {
        viewModel.apps.first(where: { $0.id == app.id })?.isSelected ?? false
    }
    
    var body: some View {
        HStack(spacing: 5) {
            Toggle("", isOn: Binding(
                get: { isChecked },
                set: { _ in viewModel.toggleSelection(for: app) },
            ))
            .toggleStyle(CustomCheckboxToggleStyle())
            .disabled(currentMode == .backup ? !app.isInstalled : false)
            
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
                        .foregroundColor(app.isInstalled || currentMode == .restore ? Color.App.primary.color(for: colorScheme) : Color.App.secondary.color(for: colorScheme))
                    
                    if currentMode == .backup, !app.isInstalled {
                        StatusBadge(
                            text: NSLocalizedString("AppList_App_Status_Not_Installed", comment: ""),
                            color: Color.App.notInstalled.color(for: colorScheme),
                            style: .compact,
                        )
                    }
                }
                
                Text(String(format: NSLocalizedString("AppList_App_Config_Paths_Count", comment: ""), app.configPaths.count))
                    .font(DesignConstants.Typography.caption)
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
                .opacity(isHovered ? 1 : 0)
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
