//
//  PreferencesView.swift
//  PocketPrefs
//
//  Application preferences with structured concurrency
//

import AppKit
import SwiftUI

struct PreferencesView: View {
    @StateObject private var preferencesManager = PreferencesManager.shared
    @State private var themeManager = ThemeManager.shared
    private var languageManager = LanguageManager.shared
    @State private var showingDirectoryPicker = false
    @State private var showingRestartAlert = false
    @State private var pendingLanguage: AppLanguage?
    @State private var languageChangeError: AppError?
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // General Section
                VStack(alignment: .leading, spacing: 16) {
                    Text(NSLocalizedString("Preferences_General", comment: ""))
                        .font(DesignConstants.Typography.headline)
                        .foregroundColor(Color.App.secondary.color(for: colorScheme))
                        .padding(.horizontal, 4)
                    
                    BackupLocationSection(
                        preferencesManager: preferencesManager,
                        showingDirectoryPicker: $showingDirectoryPicker,
                    )
                }
                
                AppearanceSection(themeManager: themeManager)
                
                LanguageSection(
                    languageManager: languageManager,
                    onLanguageChange: handleLanguageChange,
                )
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.App.background.color(for: colorScheme))
        .fileImporter(
            isPresented: $showingDirectoryPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false,
        ) { result in
            Task {
                await handleDirectorySelection(result)
            }
        }
        .alert(
            NSLocalizedString("Language_Restart_Title", comment: ""),
            isPresented: $showingRestartAlert,
        ) {
            Button(NSLocalizedString("Language_Restart_Now", comment: "")) {
                Task {
                    await restartForLanguageChange()
                }
            }
            Button(NSLocalizedString("Language_Restart_Later", comment: ""), role: .cancel) {
                saveLanguageWithoutRestart()
            }
        } message: {
            Text(NSLocalizedString("Language_Restart_Message", comment: ""))
        }
        .alert(
            "Error",
            isPresented: .constant(languageChangeError != nil),
            presenting: languageChangeError,
        ) { _ in
            Button("OK") {
                languageChangeError = nil
            }
        } message: { error in
            Text(error.localizedDescription)
        }
    }
    
    private func handleLanguageChange(_ newLanguage: AppLanguage) {
        pendingLanguage = newLanguage
        showingRestartAlert = true
    }
    
    private func restartForLanguageChange() async {
        guard let language = pendingLanguage else { return }
        
        dismiss()
        
        do {
            try await Task.sleep(for: .milliseconds(300))
            try await languageManager.setLanguage(language)
        } catch let error as AppError {
            languageChangeError = error
        } catch {
            languageChangeError = .applicationRestartFailed(error)
        }
    }
    
    private func saveLanguageWithoutRestart() {
        guard let language = pendingLanguage else { return }
        
        do {
            try languageManager.saveLanguagePreference(language)
        } catch let error as AppError {
            languageChangeError = error
        } catch {
            languageChangeError = .preferencesSaveFailed(error)
        }
    }
    
    @MainActor
    private func handleDirectorySelection(_ result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            await preferencesManager.setBackupDirectory(url.path)
            
        case .failure(let error):
            print("Directory selection error: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    PreferencesView()
        .frame(width: 750, height: 500)
}
