//
//  TempDirectory.swift
//  PocketPrefsTests
//

import Foundation

/// Creates and owns a temporary directory for use in unit tests.
/// Call `cleanup()` (or rely on `defer`) to remove it after the test.
struct TempDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: url)
    }
}
