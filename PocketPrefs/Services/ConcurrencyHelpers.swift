//
//  ConcurrencyHelpers.swift
//  PocketPrefs
//
//  Swift 6 concurrency helpers and utilities
//

import Foundation

// MARK: - Async Bridge Utilities

/// Provides utilities for bridging between async and sync contexts
/// Note: These should be used sparingly during migration to full async/await
enum ConcurrencyBridge {
    /// Execute an async operation from a synchronous context
    /// - Warning: This blocks the current thread and should be avoided where possible
    @available(*, deprecated, message: "Migrate to async/await")
    static func runBlocking<T: Sendable>(_ operation: @escaping @Sendable () async -> T) -> T {
        let semaphore = DispatchSemaphore(value: 0)
        var result: T!

        Task.detached {
            result = await operation()
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// Execute an async operation with a timeout
    static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw ConcurrencyError.timeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Concurrency Errors

enum ConcurrencyError: LocalizedError {
    case timeout
    case cancelled

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Operation timed out"
        case .cancelled:
            return "Operation was cancelled"
        }
    }
}

// MARK: - Task Extensions

extension Task where Success == Never, Failure == Never {
    /// Sleep for a specified number of seconds
    static func sleep(seconds: Double) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }

    /// Sleep for a specified number of milliseconds
    static func sleep(milliseconds: Int) async throws {
        try await Task.sleep(for: .milliseconds(milliseconds))
    }
}

// MARK: - AsyncSequence Utilities

extension AsyncSequence {
    /// Collect all elements from an async sequence into an array
    func collect() async rethrows -> [Element] {
        try await reduce(into: []) { $0.append($1) }
    }
}

// MARK: - MainActor Utilities

@MainActor
class MainActorUtilities {
    /// Run a closure on the main actor with guaranteed execution
    static func run<T: Sendable>(_ operation: @MainActor @Sendable () async throws -> T) async rethrows -> T {
        try await operation()
    }

    /// Run a closure on the main actor with a delay
    static func runAfter<T: Sendable>(
        seconds: Double,
        _ operation: @MainActor @Sendable () async throws -> T
    ) async throws -> T {
        try await Task.sleep(for: .seconds(seconds))
        return try await operation()
    }
}
