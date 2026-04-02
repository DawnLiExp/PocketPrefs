//
//  ConcurrencyUtilitiesTests.swift
//  PocketPrefsTests
//

import Testing
@testable import PocketPrefs

@Suite("ConcurrencyUtilities 单元测试")
struct ConcurrencyUtilitiesTests {

    // MARK: - withTimeout

    @Test("withTimeout：操作在时限内完成，返回正确结果")
    func timeoutSuccess() async throws {
        let result = try await ConcurrencyUtilities.withTimeout(seconds: 1) { 42 }
        #expect(result == 42)
    }

    @Test("withTimeout：操作超时时抛出 ConcurrencyError")
    func timeoutExpires() async {
        // IMPORTANT: Use ConcurrencyError.self (type match) because the enum
        // does not conform to Equatable, so specific-case matching is unavailable.
        await #expect(throws: ConcurrencyError.self) {
            try await ConcurrencyUtilities.withTimeout(seconds: 0.01) {
                try await Task.sleep(for: .seconds(5))
                return 0
            }
        }
    }

    @Test("withTimeout：操作本身抛错时错误透传，不被 timeout 吞掉")
    func timeoutErrorPassthrough() async {
        struct CustomError: Error, Equatable {}
        // Operation throws immediately (well within 1 s timeout) → error must propagate
        await #expect(throws: CustomError.self) {
            try await ConcurrencyUtilities.withTimeout(seconds: 1) {
                throw CustomError()
            }
        }
    }

    // MARK: - withRetry

    @Test("withRetry：首次成功时调用次数为 1")
    func retryFirstSuccess() async throws {
        // IMPORTANT: @Sendable closure cannot capture `var` directly in Swift 6.
        // Use @unchecked Sendable class as a mutable counter instead.
        final class Counter: @unchecked Sendable { var value = 0 }
        let counter = Counter()

        _ = try await ConcurrencyUtilities.withRetry(
            maxAttempts: 3, delay: .milliseconds(1)
        ) {
            counter.value += 1
            return counter.value
        }
        #expect(counter.value == 1)
    }

    @Test("withRetry：前 N-1 次失败，第 N 次成功，返回正确结果")
    func retrySucceedsOnThirdAttempt() async throws {
        final class Counter: @unchecked Sendable { var value = 0 }
        let counter = Counter()
        struct Fail: Error {}

        let result = try await ConcurrencyUtilities.withRetry(
            maxAttempts: 3, delay: .milliseconds(1)
        ) {
            counter.value += 1
            if counter.value < 3 { throw Fail() }
            return counter.value
        }
        #expect(result == 3)
    }

    @Test("withRetry：maxAttempts=1 时失败直接抛错，不重试")
    func retryNoRetry() async {
        struct Fail: Error {}
        await #expect(throws: Fail.self) {
            try await ConcurrencyUtilities.withRetry(maxAttempts: 1, delay: .milliseconds(1)) {
                throw Fail()
            }
        }
    }

    @Test("withRetry：全部尝试失败时，总调用次数等于 maxAttempts")
    func retryAllFail() async {
        final class Counter: @unchecked Sendable { var value = 0 }
        let counter = Counter()
        struct Fail: Error {}

        do {
            _ = try await ConcurrencyUtilities.withRetry(
                maxAttempts: 3, delay: .milliseconds(1)
            ) {
                counter.value += 1
                throw Fail()
            }
            Issue.record("Expected withRetry to throw but it returned successfully")
        } catch {
            #expect(counter.value == 3)
        }
    }

    // MARK: - Array.chunked(into:)

    @Test("chunked：5 元素按 2 分组得到 3 组，尾组只含余量")
    func chunked() {
        let chunks = [1, 2, 3, 4, 5].chunked(into: 2)
        #expect(chunks.count == 3)
        #expect(chunks[0] == [1, 2])
        #expect(chunks[1] == [3, 4])
        #expect(chunks[2] == [5])
    }

    @Test("chunked：size >= count 时结果为单个分组")
    func chunkedSingleGroup() {
        #expect([1, 2, 3].chunked(into: 10).count == 1)
        #expect([1, 2, 3].chunked(into: 3).count == 1)
    }

    @Test("chunked：空数组返回空结果")
    func chunkedEmpty() {
        #expect(([] as [Int]).chunked(into: 3).isEmpty)
    }
}
