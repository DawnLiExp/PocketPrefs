//
//  CoordinatorEventPublisher.swift
//  PocketPrefs
//
//  Event publisher for coordinator state changes
//

import Foundation
import os.log

// MARK: - Coordinator Events

enum CoordinatorEvent: Sendable {
    case appsUpdated([AppConfig])
    case backupsUpdated([BackupInfo])
    case selectedBackupUpdated(BackupInfo?)
    case operationStarted
    case operationCompleted
}

// MARK: - Operation Events

enum OperationEvent: Sendable {
    case performBackup
    case performRestore
}

// MARK: - Coordinator Event Publisher

@MainActor
final class CoordinatorEventPublisher {
    static let shared = CoordinatorEventPublisher()
    
    private let logger = Logger(subsystem: "com.pocketprefs", category: "CoordinatorEventPublisher")
    private var continuations: [UUID: AsyncStream<CoordinatorEvent>.Continuation] = [:]
    
    private init() {}
    
    deinit {
        continuations.values.forEach { $0.finish() }
    }
    
    // MARK: - Subscription
    
    func subscribe() -> AsyncStream<CoordinatorEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<CoordinatorEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(10),
        )
        
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.continuations.removeValue(forKey: id)
                self?.logger.debug("Coordinator event subscriber unregistered: \(id)")
            }
        }
        
        continuations[id] = continuation
        logger.debug("Coordinator event subscriber registered: \(id)")
        
        return stream
    }
    
    // MARK: - Publishing
    
    func publish(_ event: CoordinatorEvent) {
        logger.debug("Broadcasting coordinator event to \(self.continuations.count) subscribers")
        continuations.values.forEach { $0.yield(event) }
    }
}

// MARK: - Operation Event Publisher

@MainActor
final class OperationEventPublisher {
    static let shared = OperationEventPublisher()
    
    private let logger = Logger(subsystem: "com.pocketprefs", category: "OperationEventPublisher")
    private var continuations: [UUID: AsyncStream<OperationEvent>.Continuation] = [:]
    
    private init() {}
    
    deinit {
        continuations.values.forEach { $0.finish() }
    }
    
    // MARK: - Subscription
    
    func subscribe() -> AsyncStream<OperationEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<OperationEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(5),
        )
        
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.continuations.removeValue(forKey: id)
                self?.logger.debug("Operation event subscriber unregistered: \(id)")
            }
        }
        
        continuations[id] = continuation
        logger.debug("Operation event subscriber registered: \(id)")
        
        return stream
    }
    
    // MARK: - Publishing
    
    func publish(_ event: OperationEvent) {
        logger.debug("Broadcasting operation event to \(self.continuations.count) subscribers")
        continuations.values.forEach { $0.yield(event) }
    }
}
