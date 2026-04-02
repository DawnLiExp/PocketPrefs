//
//  BackupServiceUtilityTests.swift
//  PocketPrefsTests
//

import Foundation
import Testing
@testable import PocketPrefs

@Suite("BackupService 工具方法")
struct BackupServiceUtilityTests {

    let service = BackupService()

    // MARK: - sanitizeName

    @Test("sanitizeName：正常名称原样返回")
    func cleanName() async {
        let result = await service.sanitizeName("Visual Studio Code")
        #expect(result == "Visual Studio Code")
    }

    @Test("sanitizeName：斜杠替换为下划线")
    func slashReplaced() async {
        let result = await service.sanitizeName("a/b")
        #expect(result == "a_b")
    }

    @Test("sanitizeName：所有非法字符均被替换")
    func allForbiddenChars() async {
        // macOS + Windows forbidden set used by sanitizeName
        let input = #"\/:*?"<>|"#
        let result = await service.sanitizeName(input)
        for ch in #"\/:*?"<>|"# {
            #expect(!result.contains(ch), "Result still contains '\(ch)'")
        }
    }

    @Test("sanitizeName：空字符串返回空字符串")
    func emptyString() async {
        let result = await service.sanitizeName("")
        #expect(result == "")
    }

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
