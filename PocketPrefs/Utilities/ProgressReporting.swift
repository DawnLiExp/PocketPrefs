//
//  ProgressReporting.swift
//  PocketPrefs
//
//  Progress reporting utilities for backup and restore operations
//

import Foundation

// MARK: - Progress Update

/// Progress update containing completion fraction and optional status message.
/// `fraction` is always clamped to [0.0, 1.0]; NaN / Infinity are treated as 0.0.
struct ProgressUpdate: Equatable {
    let fraction: Double // guaranteed: 0.0 ... 1.0
    let message: String?

    // MARK: Convenience Constants

    /// Zero-progress sentinel - use at operation start or to reset state.
    static let idle = ProgressUpdate(fraction: 0.0)

    /// Full-progress sentinel without a message - use when no status text is needed.
    static let finished = ProgressUpdate(fraction: 1.0)

    // MARK: Initializers

    /// Initialize with direct fraction value.
    /// - NaN and Infinity are normalized to 0.0.
    /// - Values outside [0, 1] are clamped.
    init(fraction: Double, message: String? = nil) {
        if fraction.isNaN || fraction.isInfinite {
            self.fraction = 0.0
        } else {
            self.fraction = max(0.0, min(1.0, fraction))
        }
        self.message = message
    }

    /// Initialize with discrete completion counts.
    /// - `total <= 0` with `completed > 0` -> 1.0 (treat as complete).
    /// - `total <= 0` with `completed <= 0` -> 0.0.
    /// - `completed > total` is clamped to 1.0.
    init(completed: Int, total: Int, message: String? = nil) {
        if total <= 0 {
            self.fraction = completed > 0 ? 1.0 : 0.0
        } else {
            self.fraction = max(0.0, min(1.0, Double(completed) / Double(total)))
        }
        self.message = message
    }

    // MARK: Legacy Static Factories (kept for call-sites that pass a message)

    /// Create an initial (0%) progress update - prefer `.idle` when no message is needed.
    @available(*, deprecated, renamed: "idle")
    static func initial() -> ProgressUpdate {
        .idle
    }

    /// Create a completion (100%) update with an optional status message.
    static func completed(message: String? = nil) -> ProgressUpdate {
        ProgressUpdate(fraction: 1.0, message: message)
    }
}

// MARK: - Progress Handler

/// Type alias for progress reporting closure
/// Must be called on MainActor to update UI safely
typealias ProgressHandler = @MainActor @Sendable (ProgressUpdate) async -> Void
