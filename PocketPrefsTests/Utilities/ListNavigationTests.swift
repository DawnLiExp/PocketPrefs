import Testing

@testable import PocketPrefs

@Suite("列表键盘导航")
struct ListNavigationTests {
    @Test("上下键按可见顺序移动并停在边界")
    func navigate() {
        let ids = ["A", "B", "C"]
        #expect(ListNavigation.destination(in: ids, from: "A", offset: 1) == "B")
        #expect(ListNavigation.destination(in: ids, from: "B", offset: -1) == "A")
        #expect(ListNavigation.destination(in: ids, from: "A", offset: -1) == "A")
        #expect(ListNavigation.destination(in: ids, from: "C", offset: 1) == "C")
    }

    @Test("空列表与筛选后失效焦点有确定行为")
    func missingFocus() {
        #expect(ListNavigation.destination(in: [], from: "A", offset: 1) == nil)
        #expect(ListNavigation.destination(in: ["B", "C"], from: "A", offset: 1) == "B")
        #expect(ListNavigation.destination(in: ["B", "C"], from: nil, offset: -1) == "C")
    }
}