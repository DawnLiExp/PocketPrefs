//
//  DetailContainerView.swift
//  PocketPrefs
//
//  Detail view routing and container
//

import SwiftUI

struct DetailContainerView: View {
    let selectedApp: AppConfig?
    let currentMode: MainView.AppMode
    @Binding var showingRestorePicker: Bool
    @Environment(MainCoordinator.self) private var coordinator
    @Environment(MainViewModel.self) private var mainViewModel

    var body: some View {
        DetailContent(
            selectedApp: selectedApp,
            coordinator: coordinator,
            mainViewModel: mainViewModel,
            currentMode: currentMode,
            showingRestorePicker: $showingRestorePicker,
        )
        .transaction { transaction in
            // IMPORTANT: detail content must not inherit selection animations; animating text/layout changes causes visible ghosting when switching apps.
            transaction.animation = nil
        }
    }
}

private struct DetailContent: View {
    let selectedApp: AppConfig?
    let mainViewModel: MainViewModel
    let currentMode: MainView.AppMode
    @Binding var showingRestorePicker: Bool
    @State private var viewModel: DetailViewModel

    init(
        selectedApp: AppConfig?,
        coordinator: MainCoordinator,
        mainViewModel: MainViewModel,
        currentMode: MainView.AppMode,
        showingRestorePicker: Binding<Bool>,
    ) {
        self.selectedApp = selectedApp
        self.mainViewModel = mainViewModel
        self.currentMode = currentMode
        self._showingRestorePicker = showingRestorePicker
        self._viewModel = State(wrappedValue: DetailViewModel(
            coordinator: coordinator,
            mainViewModel: mainViewModel
        ))
    }

    var body: some View {
        if mainViewModel.isProcessing {
            ProgressView(
                progress: mainViewModel.currentProgress,
                messageHistory: mainViewModel.statusMessageHistory,
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if currentMode == .backup {
            if let app = selectedApp {
                AppDetailView(
                    app: app,
                    currentMode: currentMode,
                    showingRestorePicker: $showingRestorePicker,
                    viewModel: viewModel,
                )
            } else {
                BackupPlaceholderView(viewModel: viewModel)
            }
        } else {
            RestorePlaceholderView(viewModel: viewModel)
        }
    }
}
