//
//  ProgressReporting.swift
//  PocketPrefs
//
//  Progress reporting utilities for backup and restore operations
//

import Foundation

// MARK: - Progress Update

/// Progress update containing completion fraction and optional status message
struct ProgressUpdate: Sendable {
    let fraction: Double  // 0.0 to 1.0
    let message: String?
    
    /// Initialize with discrete completion counts
    init(completed: Int, total: Int, message: String? = nil) {
        self.fraction = total > 0 ? min(Double(completed) / Double(total), 1.0) : 0.0
        self.message = message
    }
    
    /// Initialize with direct fraction value
    init(fraction: Double, message: String? = nil) {
        self.fraction = min(max(fraction, 0.0), 1.0)
        self.message = message
    }
    
    /// Create initial progress update (0%)
    static func initial() -> ProgressUpdate {
        ProgressUpdate(fraction: 0.0, message: nil)
    }
    
    /// Create completion progress update (100%)
    static func completed(message: String? = nil) -> ProgressUpdate {
        ProgressUpdate(fraction: 1.0, message: message)
    }
}

// MARK: - Progress Handler

/// Type alias for progress reporting closure
/// Must be called on MainActor to update UI safely
typealias ProgressHandler = @MainActor @Sendable (ProgressUpdate) async -> Void
