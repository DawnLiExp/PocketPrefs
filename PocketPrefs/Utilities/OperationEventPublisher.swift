//
//  OperationEventPublisher.swift
//  PocketPrefs
//
//  Event publisher for user-initiated backup and restore commands.
//  Distinct from CoordinatorEventPublisher (state sync): this publisher carries
//  imperative commands, not state snapshots.
//

import Foundation
import os.log

// MARK: - Operation Events

enum OperationEvent {
    case performBackup
    case performRestore
}

// MARK: - Operation Event Publisher

@MainActor
final class OperationEventPublisher {
    static let shared = OperationEventPublisher()

    private let logger = Logger(subsystem: "com.me2.PocketPrefs", category: "OperationEventPublisher")
    private var continuations: [UUID: AsyncStream<OperationEvent>.Continuation] = [:]

    private init() {}

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
