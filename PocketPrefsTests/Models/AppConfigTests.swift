//
//  AppConfigTests.swift
//  PocketPrefsTests
//

import Foundation
import Testing
@testable import PocketPrefs

@Suite("AppConfig 模型")
struct AppConfigTests {

    // MARK: - Equatable
    // AppConfig.== is defined as: lhs.id == rhs.id && lhs.name == rhs.name
    //   && lhs.configPaths == rhs.configPaths
    //   && lhs.category == rhs.category && lhs.isUserAdded == rhs.isUserAdded

    @Test("Equatable：赋值拷贝（id 相同）时相等")
    func equalitySameInstance() {
        let a = AppConfig(name: "Git", bundleId: "git", configPaths: ["~/.gitconfig"])
        let b = a   // value-type copy, id preserved
        #expect(a == b)
    }

    @Test("Equatable：相同 bundleId 的两次 init 视为相等（确定性 id）")
    func equalityDeterministicId() {
        let a = AppConfig(name: "Git", bundleId: "git", configPaths: ["~/.gitconfig"])
        let b = AppConfig(name: "Git", bundleId: "git", configPaths: ["~/.gitconfig"])
        #expect(a == b)
    }

    // MARK: - Codable

    @Test("Codable 往返：关键字段还原")
    func codableRoundTrip() throws {
        let original = AppConfig(
            name: "Zed",
            bundleId: "dev.zed.Zed",
            configPaths: ["~/.config/zed/settings.json", "~/.config/zed/keymap.json"],
            category: .development,
            isUserAdded: true
        )
        let data    = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        #expect(decoded.name        == original.name)
        #expect(decoded.bundleId    == original.bundleId)
        #expect(decoded.configPaths == original.configPaths)
        #expect(decoded.category    == original.category)
        #expect(decoded.isUserAdded == original.isUserAdded)
        // id 由 bundleId 确定性派生，解码后与原值一致
        #expect(decoded.id == original.id)
    }

    @Test("Codable：isSelected / isInstalled 不参与编码，解码后使用默认值")
    func codableOmitsTransientFields() throws {
        var original = AppConfig(name: "Arc", bundleId: "company.thebrowser.Browser", configPaths: [])
        original.isSelected  = true
        original.isInstalled = false

        let data    = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        // CodingKeys does not include isSelected or isInstalled → reset to defaults
        #expect(decoded.isSelected  == false)
        #expect(decoded.isInstalled == true)
    }

    // MARK: - presetConfigs integrity

    @Test("presetConfigs 中无重复 bundleId")
    func noDuplicateBundleIds() {
        let ids = AppConfig.presetConfigs.map(\.bundleId)
        #expect(Set(ids).count == ids.count)
    }

    @Test("所有 preset 的 configPaths 非空")
    func presetConfigPathsNonEmpty() {
        for preset in AppConfig.presetConfigs {
            #expect(!preset.configPaths.isEmpty, "Empty configPaths for preset: \(preset.name)")
        }
    }

    @Test("所有 preset 的 createdAt 为 epoch 锚点（用于 dateAddedDescending 排序）")
    func presetCreatedAtIsEpoch() {
        let epoch = Date(timeIntervalSince1970: 0)
        for preset in AppConfig.presetConfigs {
            #expect(preset.createdAt == epoch, "\(preset.name).createdAt is not epoch")
        }
    }

    @Test("所有 preset 的 isUserAdded 为 false")
    func presetIsUserAddedFalse() {
        for preset in AppConfig.presetConfigs {
            #expect(!preset.isUserAdded, "\(preset.name) should not be isUserAdded")
        }
    }
}
