//
//  BackupModelsTests.swift
//  PocketPrefsTests
//

import Foundation
import Testing
@testable import PocketPrefs

// MARK: - BackupInfo.formattedName

@Suite("BackupInfo.formattedName")
struct BackupInfoFormattedNameTests {

    @Test("标准时间戳格式化为非空本地化字符串，且不含原始下划线分隔符")
    func validTimestamp() {
        let info = BackupInfo(path: "/tmp", name: "Backup_2025-09-27_14-35-00", date: .now)
        #expect(!info.formattedName.isEmpty)
        // 原始时间戳中的 "_" 应被本地化日期格式替换掉
        #expect(!info.formattedName.contains("_"))
    }

    @Test("无 Backup_ 前缀时原样返回 name 本身")
    func missingPrefix() {
        let info = BackupInfo(path: "/tmp", name: "SomeOtherFolder", date: .now)
        #expect(info.formattedName == "SomeOtherFolder")
    }

    @Test("日期部分格式错误时返回去除前缀后的原始 dateString")
    func malformedDate() {
        let info = BackupInfo(path: "/tmp", name: "Backup_not-a-date", date: .now)
        #expect(info.formattedName == "not-a-date")
    }
}

// MARK: - BackupResult.statusMessage

@Suite("BackupResult.statusMessage")
struct BackupResultStatusTests {

    @Test("完全成功时 statusMessage 包含 ✅")
    func success() {
        let r = BackupResult(successCount: 3, failedApps: [], totalProcessed: 3)
        #expect(r.isCompleteSuccess)
        #expect(r.statusMessage.contains("✅"))
    }

    @Test("部分失败时 statusMessage 包含 ⚠️ 及失败的 app 名")
    func partial() {
        struct E: Error {}
        let r = BackupResult(
            successCount: 1,
            failedApps: [("MyApp", E())],
            totalProcessed: 2
        )
        #expect(!r.isCompleteSuccess)
        #expect(r.statusMessage.contains("⚠️"))
        #expect(r.statusMessage.contains("MyApp"))
    }

    @Test("successCount 为 0 且无失败时不含 ✅ / ⚠️")
    func noApps() {
        let r = BackupResult(successCount: 0, failedApps: [], totalProcessed: 0)
        #expect(!r.isCompleteSuccess)
        #expect(!r.statusMessage.contains("✅"))
        #expect(!r.statusMessage.contains("⚠️"))
    }
}

// MARK: - RestoreResult.statusMessage

@Suite("RestoreResult.statusMessage")
struct RestoreResultStatusTests {

    @Test("完全成功时 statusMessage 包含 ✅")
    func success() {
        let r = RestoreResult(successCount: 2, failedApps: [], totalProcessed: 2)
        #expect(r.isCompleteSuccess)
        #expect(r.statusMessage.contains("✅"))
    }

    @Test("部分失败时 statusMessage 包含 ⚠️ 及失败的 app 名")
    func partial() {
        struct E: Error {}
        let r = RestoreResult(
            successCount: 1,
            failedApps: [("TargetApp", E())],
            totalProcessed: 2
        )
        #expect(!r.isCompleteSuccess)
        #expect(r.statusMessage.contains("⚠️"))
        #expect(r.statusMessage.contains("TargetApp"))
    }

    @Test("successCount 为 0 且无失败时不含 ✅ / ⚠️")
    func noApps() {
        let r = RestoreResult(successCount: 0, failedApps: [], totalProcessed: 0)
        #expect(!r.isCompleteSuccess)
        #expect(!r.statusMessage.contains("✅"))
        #expect(!r.statusMessage.contains("⚠️"))
    }
}
