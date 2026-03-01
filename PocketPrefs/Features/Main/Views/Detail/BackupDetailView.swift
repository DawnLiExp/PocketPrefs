//
//  BackupDetailView.swift
//  PocketPrefs
//
//  Backup mode detail views
//

import SwiftUI

// MARK: - AppDetailView

struct AppDetailView: View {
    let app: AppConfig
    var coordinator: MainCoordinator
    let currentMode: MainView.AppMode
    @Binding var showingRestorePicker: Bool
    var viewModel: DetailViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            AppDetailHeader(
                app: app,
                currentMode: currentMode,
            )

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(app.configPaths, id: \.self) { path in
                        ConfigPathItem(path: path)
                    }
                }
                .padding(16)
            }

            Spacer()

            HStack {
                Spacer()

                Button(action: { viewModel.performBackup() }) {
                    Label(
                        NSLocalizedString("Detail_Action_Backup_Selected", comment: ""),
                        systemImage: "arrow.up.circle.fill",
                    )
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!viewModel.hasValidBackupSelection)
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - BackupPlaceholderView

struct BackupPlaceholderView: View {
    var coordinator: MainCoordinator
    var viewModel: DetailViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "document.badge.gearshape.fill")
                        .font(.system(size: 108))
                        .foregroundColor(Color.App.accent.color(for: colorScheme).opacity(0.7))
                        .fadeInScaleAnimation()

                    Text(NSLocalizedString("Detail_Placeholder_Select_App", comment: ""))
                        .font(DesignConstants.Typography.headline)
                        .foregroundColor(Color.App.secondary.color(for: colorScheme))
                        .breathingPulseAnimation()
                }

                Spacer()

                VStack(spacing: 112) {
                    Button(action: { viewModel.performBackup() }) {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 20))
                            Text(NSLocalizedString("Detail_Placeholder_Quick_Backup_All_Selected", comment: ""))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!viewModel.hasValidBackupSelection)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            UserInfoView()
                .padding(.top, 5)
                .padding(.trailing, 5)
        }
    }
}
