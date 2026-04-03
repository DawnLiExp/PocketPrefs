//
//  ProgressUpdateTests.swift
//  PocketPrefsTests
//

import Testing
@testable import PocketPrefs

@Suite("ProgressUpdate 边界防御")
struct ProgressUpdateTests {

    // MARK: - fraction init

    @Test("正常值原样保留")
    func normalFraction() {
        #expect(ProgressUpdate(fraction: 0.5).fraction == 0.5)
    }

    @Test("fraction: NaN -> 0.0")
    func nanFraction() {
        #expect(ProgressUpdate(fraction: .nan).fraction == 0.0)
    }

    @Test("fraction: +Infinity -> 0.0")
    func infinityFraction() {
        #expect(ProgressUpdate(fraction: .infinity).fraction == 0.0)
    }

    @Test("fraction < 0 -> 0.0")
    func negativeFraction() {
        #expect(ProgressUpdate(fraction: -2.3).fraction == 0.0)
    }

    @Test("fraction > 1 -> 1.0")
    func overflowFraction() {
        #expect(ProgressUpdate(fraction: 1.5).fraction == 1.0)
    }

    // MARK: - completed/total init

    @Test("completed:0 total:0 -> 0.0")
    func zeroZero() {
        #expect(ProgressUpdate(completed: 0, total: 0).fraction == 0.0)
    }

    @Test("completed:5 total:0 -> 1.0（有完成项但总数无效）")
    func completedWithZeroTotal() {
        #expect(ProgressUpdate(completed: 5, total: 0).fraction == 1.0)
    }

    @Test("completed > total -> 1.0（夹值）")
    func completedExceedsTotal() {
        #expect(ProgressUpdate(completed: 10, total: 5).fraction == 1.0)
    }

    @Test("completed < 0 -> 0.0")
    func negativeCompleted() {
        #expect(ProgressUpdate(completed: -1, total: 5).fraction == 0.0)
    }

    // MARK: - Static constants

    @Test(".idle fraction == 0.0")
    func idleConstant() {
        #expect(ProgressUpdate.idle.fraction == 0.0)
        #expect(ProgressUpdate.idle.message == nil)
    }

    @Test(".finished fraction == 1.0")
    func finishedConstant() {
        #expect(ProgressUpdate.finished.fraction == 1.0)
        #expect(ProgressUpdate.finished.message == nil)
    }

    // MARK: - Equatable

    @Test("Equatable：相同值相等")
    func equatable() {
        #expect(ProgressUpdate(fraction: 0.5, message: "test") ==
                ProgressUpdate(fraction: 0.5, message: "test"))
    }

    @Test("Equatable：message 不同则不等")
    func equatableDifferentMessage() {
        #expect(ProgressUpdate(fraction: 0.5, message: "a") !=
                ProgressUpdate(fraction: 0.5, message: "b"))
    }
}
