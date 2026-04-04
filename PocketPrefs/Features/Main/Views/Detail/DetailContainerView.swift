//
//  DetailContainerView.swift
//  PocketPrefs
//
//  Detail view routing and container
//

import SwiftUI

struct DetailContainerView: View {
    let selectedAppID: AppConfig.ID?
    var coordinator: MainCoordinator
    var mainViewModel: MainViewModel
    let currentMode: MainView.AppMode
    @Binding var showingRestorePicker: Bool

    @State private var viewModel: DetailViewModel

    init(
        selectedAppID: AppConfig.ID?,
        coordinator: MainCoordinator,
        mainViewModel: MainViewModel,
        currentMode: MainView.AppMode,
        showingRestorePicker: Binding<Bool>,
    ) {
        self.selectedAppID = selectedAppID
        self.coordinator = coordinator
        self.mainViewModel = mainViewModel
        self.currentMode = currentMode
        self._showingRestorePicker = showingRestorePicker
        self._viewModel = State(wrappedValue: DetailViewModel(mainViewModel: mainViewModel))
    }

    var body: some View {
        if mainViewModel.coordinator.isProcessing {
            ProgressView(
                progress: mainViewModel.currentProgress,
                messageHistory: mainViewModel.statusMessageHistory,
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if currentMode == .backup {
            if let app = selectedApp {
                AppDetailView(
                    app: app,
                    coordinator: coordinator,
                    currentMode: currentMode,
                    showingRestorePicker: $showingRestorePicker,
                    viewModel: viewModel,
                )
            } else {
                BackupPlaceholderView(coordinator: coordinator, viewModel: viewModel)
            }
        } else {
            RestorePlaceholderView(coordinator: coordinator, viewModel: viewModel)
        }
    }

    private var selectedApp: AppConfig? {
        guard let selectedAppID else { return nil }
        return coordinator.apps.first(where: { $0.id == selectedAppID })
    }
}
