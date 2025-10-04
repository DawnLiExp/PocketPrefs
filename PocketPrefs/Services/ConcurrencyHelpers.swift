//
//  ConcurrencyHelpers.swift
//  PocketPrefs
//
//  Swift 6 concurrency utilities
//

import Foundation

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

// MARK: - Timeout Utilities

enum ConcurrencyUtilities {
    /// Execute async operation with timeout
    /// - Parameters:
    ///   - seconds: Timeout duration
    ///   - operation: Async operation to execute
    /// - Returns: Operation result
    /// - Throws: `ConcurrencyError.timeout` if operation exceeds time limit
    static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T,
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw ConcurrencyError.timeout
            }

            guard let result = try await group.next() else {
                throw ConcurrencyError.cancelled
            }

            group.cancelAll()
            return result
        }
    }

    /// Execute async operation with retry logic
    /// - Parameters:
    ///   - maxAttempts: Maximum retry attempts
    ///   - delay: Delay between retries
    ///   - operation: Async operation to execute
    /// - Returns: Operation result
    static func withRetry<T: Sendable>(
        maxAttempts: Int = 3,
        delay: Duration = .seconds(1),
        operation: @escaping @Sendable () async throws -> T,
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1 ... maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    try await Task.sleep(for: delay)
                }
            }
        }

        throw lastError ?? ConcurrencyError.cancelled
    }
}

// MARK: - Task Extensions

extension Task where Success == Never, Failure == Never {
    /// Sleep for specified seconds
    static func sleep(seconds: Double) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }

    /// Sleep for specified milliseconds
    static func sleep(milliseconds: Int) async throws {
        try await Task.sleep(for: .milliseconds(milliseconds))
    }
}

// MARK: - AsyncSequence Extensions

extension AsyncSequence {
    /// Collect all elements into array
    func collect() async rethrows -> [Element] {
        try await reduce(into: []) { $0.append($1) }
    }

    /// Collect elements up to limit
    func collect(upTo limit: Int) async rethrows -> [Element] {
        var elements: [Element] = []
        elements.reserveCapacity(limit)

        for try await element in self {
            elements.append(element)
            if elements.count >= limit {
                break
            }
        }

        return elements
    }
}

// MARK: - Array Extensions

extension Array {
    /// Split array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
