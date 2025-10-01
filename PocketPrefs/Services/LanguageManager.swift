//
//  LanguageManager.swift
//  PocketPrefs
//
//  Language preference management with SwiftUI observation
//

import Foundation
import os.log
import SwiftUI

// MARK: - Language Manager

@MainActor
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    private let logger = Logger(subsystem: "com.pocketprefs", category: "LanguageManager")
    
    @Published var currentLanguage: AppLanguage = .english
    @AppStorage("preferredLanguage") private var storedLanguage: String = ""
    
    private init() {
        if storedLanguage.isEmpty {
            let detected = Self.detectSystemLanguage()
            currentLanguage = detected
            storedLanguage = detected.rawValue
        } else {
            currentLanguage = AppLanguage(rawValue: storedLanguage) ?? .english
        }
    }
    
    func setLanguage(_ language: AppLanguage) {
        guard currentLanguage != language else { return }
        
        withAnimation(DesignConstants.Animation.smooth) {
            currentLanguage = language
            storedLanguage = language.rawValue
        }
        
        logger.info("Language changed: \(language.rawValue)")
    }
    
    private static func detectSystemLanguage() -> AppLanguage {
        let preferredLanguages = Locale.preferredLanguages
        if let first = preferredLanguages.first, first.hasPrefix("zh-Hans") {
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
            return NSLocalizedString("Language_SimplifiedChinese", comment: "")
        case .english:
            return NSLocalizedString("Language_English", comment: "")
        }
    }
    
    var localeIdentifier: String {
        rawValue
    }
}
