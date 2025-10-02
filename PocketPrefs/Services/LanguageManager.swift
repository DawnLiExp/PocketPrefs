//
//  LanguageManager.swift
//  PocketPrefs
//
//  Language preference management with structured concurrency
//

import Foundation
import os.log
import SwiftUI

// MARK: - Language Manager

@MainActor
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    private let logger = Logger(subsystem: "com.pocketprefs", category: "LanguageManager")
    private static let languageKey = "PocketPrefsLanguage"
    private static let appleLanguagesKey = "AppleLanguages"
    
    @Published var currentLanguage: AppLanguage
    
    private init() {
        if let stored = UserDefaults.standard.string(forKey: Self.languageKey),
           let language = AppLanguage(rawValue: stored)
        {
            self.currentLanguage = language
            logger.info("Loaded language: \(stored)")
        } else {
            self.currentLanguage = Self.detectSystemLanguage()
            logger.info("System language: \(self.currentLanguage.rawValue)")
        }
    }
    
    func setLanguage(_ language: AppLanguage) async throws {
        logger.info("Setting language: \(language.rawValue)")
        
        do {
            try saveLanguagePreference(language)
            try await restartApplication()
        } catch {
            logger.error("Language change failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    func saveLanguagePreference(_ language: AppLanguage) throws {
        UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
        UserDefaults.standard.set([language.rawValue], forKey: Self.appleLanguagesKey)
        
        guard UserDefaults.standard.synchronize() else {
            throw AppError.preferencesSaveFailed(
                NSError(domain: "com.pocketprefs", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "UserDefaults synchronize failed"
                ])
            )
        }
        
        logger.info("Language preference saved: \(language.rawValue)")
    }
    
    private func restartApplication() async throws {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", path]
        
        do {
            try task.run()
            logger.info("New instance launched")
            
            try await Task.sleep(for: .milliseconds(100))
            
            logger.info("Terminating current instance")
            NSApplication.shared.terminate(nil)
        } catch {
            logger.error("Restart failed: \(error.localizedDescription)")
            throw AppError.applicationRestartFailed(error)
        }
    }
    
    private static func detectSystemLanguage() -> AppLanguage {
        if let langs = UserDefaults.standard.array(forKey: appleLanguagesKey) as? [String],
           let first = langs.first,
           first.hasPrefix("zh")
        {
            return .simplifiedChinese
        }
        
        if let first = Locale.preferredLanguages.first,
           first.hasPrefix("zh")
        {
            return .simplifiedChinese
        }
        
        return .english
    }
}

// MARK: - App Language

enum AppLanguage: String, CaseIterable, Sendable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"
    
    var displayName: String {
        switch self {
        case .simplifiedChinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }
}
