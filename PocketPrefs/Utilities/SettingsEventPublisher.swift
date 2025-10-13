//
//  SettingsEventPublisher.swift
//  PocketPrefs
//
//  Event publisher for settings lifecycle events
//

import Foundation
import os.log

// MARK: - Settings Events

enum SettingsEvent: Sendable {
    case didClose
}

// MARK: - Settings Event Publisher

@MainActor
final class SettingsEventPublisher {
    static let shared = SettingsEventPublisher()
    
    private let logger = Logger(subsystem: "com.pocketprefs", category: "SettingsEventPublisher")
    private var continuations: [UUID: AsyncStream<SettingsEvent>.Continuation] = [:]
    
    private init() {}
    
    deinit {
        let conts = continuations.values
        conts.forEach { $0.finish() }
    }
    
    // MARK: - Subscription
    
    func subscribe() -> AsyncStream<SettingsEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<SettingsEvent>.makeStream(
            bufferingPolicy: .unbounded,
        )
        
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.continuations.removeValue(forKey: id)
                self?.logger.debug("SettingsEventPublisher subscriber unregistered: \(id)")
            }
        }
        
        continuations[id] = continuation
        logger.debug("SettingsEventPublisher subscriber registered: \(id)")
        
        return stream
    }
    
    // MARK: - Publishing
    
    func publishDidClose() {
        logger.debug("Broadcasting settings close event to \(self.continuations.count) subscribers")
        continuations.values.forEach { $0.yield(.didClose) }
    }
}
