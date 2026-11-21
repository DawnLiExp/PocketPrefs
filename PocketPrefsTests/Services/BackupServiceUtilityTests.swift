//
//  BackupServiceUtilityTests.swift
//  PocketPrefsTests
//

import Foundation
import Testing
@testable import PocketPrefs

@Suite("BackupService 工具方法")
struct BackupServiceUtilityTests {

    // MARK: - dateFormatter

    @Test("dateFormatter 解析合法备份时间戳")
    func validTimestamp() {
        let date = BackupService.dateFormatter.date(from: "2025-09-27_14-35-00")
        #expect(date != nil)
    }

    @Test("dateFormatter 拒绝非法格式")
    func invalidTimestamp() {
        #expect(BackupService.dateFormatter.date(from: "not-a-date") == nil)
        #expect(BackupService.dateFormatter.date(from: "2025/09/27") == nil)
        #expect(BackupService.dateFormatter.date(from: "") == nil)
    }
}
