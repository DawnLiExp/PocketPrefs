import SwiftUI

enum ListNavigation {
    static func destination(in ids: [String], from current: String?, offset: Int) -> String? {
        guard !ids.isEmpty else { return nil }
        guard let current, let index = ids.firstIndex(of: current) else {
            return offset < 0 ? ids.last : ids.first
        }
        return ids[max(0, min(ids.count - 1, index + offset))]
    }
}

private struct KeyboardListModifier: ViewModifier {
    let ids: [String]
    let focus: FocusState<String?>.Binding
    let onNavigate: (String) -> Void

    func body(content: Content) -> some View {
        content
            .onKeyPress(.upArrow) { move(-1) }
            .onKeyPress(.downArrow) { move(1) }
            .onChange(of: ids) { _, values in
                if let current = focus.wrappedValue, !values.contains(current) {
                    focus.wrappedValue = nil
                }
            }
    }

    private func move(_ offset: Int) -> KeyPress.Result {
        guard let next = ListNavigation.destination(in: ids, from: focus.wrappedValue, offset: offset) else { return .ignored }
        focus.wrappedValue = next
        onNavigate(next)
        return .handled
    }
}

private struct RowFocusOutline: ViewModifier {
    let isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.overlay {
            RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius)
                .stroke(isFocused ? Color.App.accent.color(for: colorScheme) : .clear, lineWidth: 2)
                .allowsHitTesting(false)
        }
    }
}

private struct KeyboardFocusOutline: ViewModifier {
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .focusEffectDisabled()
            .padding(2)
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isFocused ? Color.accentColor : .clear, lineWidth: 2)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func keyboardListNavigation(ids: [String], focus: FocusState<String?>.Binding, onNavigate: @escaping (String) -> Void = { _ in }) -> some View {
        modifier(KeyboardListModifier(ids: ids, focus: focus, onNavigate: onNavigate))
    }

    func rowFocusOutline(_ isFocused: Bool) -> some View {
        modifier(RowFocusOutline(isFocused: isFocused))
    }

    func keyboardFocusOutline() -> some View {
        modifier(KeyboardFocusOutline())
    }
}