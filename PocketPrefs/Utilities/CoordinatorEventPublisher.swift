//
//  CoordinatorEventPublisher.swift
//  PocketPrefs
//
//  Event publisher for coordinator state changes.
//  Scheduled for full removal in Phase 3 (Step 6-7) of the refactoring.
//  OperationEvent / OperationEventPublisher have been moved to OperationEventPublisher.swift.
//

import Foundation
import os.log

// MARK: - Coordinator Events

enum CoordinatorEvent {
    case appsUpdated([AppConfig])
    case backupsUpdated([BackupInfo])
    case selectedBackupUpdated(BackupInfo?)
    case operationStarted
    case operationCompleted
}

// MARK: - Coordinator Event Publisher

@MainActor
final class CoordinatorEventPublisher {
    static let shared = CoordinatorEventPublisher()

    private let logger = Logger(subsystem: "com.me2.PocketPrefs", category: "CoordinatorEventPublisher")
    private var continuations: [UUID: AsyncStream<CoordinatorEvent>.Continuation] = [:]

    private init() {}

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
