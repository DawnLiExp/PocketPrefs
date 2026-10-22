import Foundation
import Testing
@testable import PocketPrefs

@Suite("配置路径输入")
struct ConfigurationPathInputTests {
    @Test("拒绝空白输入", arguments: ["", " ", "\n\t"])
    func emptyInput(_ draft: String) {
        #expect(ConfigurationPathInput.validate(draft, existing: []) == .failure(.empty))
    }

    @Test("新增和编辑均拒绝重复，并识别 home 的两种写法")
    func duplicatePaths() {
        let path = "~/Library/PocketPrefs-Test/config.json"
        let expanded = NSString(string: path).expandingTildeInPath
        #expect(ConfigurationPathInput.validate(expanded, existing: [path]) == .failure(.duplicate))
        #expect(ConfigurationPathInput.validate(path, existing: [path, "~/other"], editingIndex: 1) == .failure(.duplicate))
        #expect(ConfigurationPathInput.validate(path, existing: [path], editingIndex: 0) == .success(path))
    }

    @Test("接受不存在的路径并原样保留，过期编辑索引报错")
    func preservePathSemantics() {
        let draft = "~/missing/../symbolic link/config "
        #expect(ConfigurationPathInput.validate(draft, existing: []) == .success(draft))
        #expect(ConfigurationPathInput.validate(draft, existing: [], editingIndex: 1) == .failure(.unavailable))
    }
}
