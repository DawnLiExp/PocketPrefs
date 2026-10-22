//
//  CustomCheckboxToggleStyle.swift
//  PocketPrefs
//
//  Custom checkbox toggle style for a unified UI appearance.
//

import SwiftUI

/// Custom ToggleStyle implementation providing consistent checkbox appearance
/// across the application, integrating with the adaptive color system.
struct CustomCheckboxToggleStyle: ToggleStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        Toggle(isOn: configuration.$isOn) {
            configuration.label
        }
        .toggleStyle(.checkbox)
        .tint(Color.App.accent.color(for: colorScheme))
    }
}

// MARK: - Preview

#Preview("Light") {
    CheckboxPreview()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    CheckboxPreview()
        .preferredColorScheme(.dark)
}

/// Preview container demonstrating various checkbox states
private struct CheckboxPreview: View {
    @State private var states = [true, false, true, false]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(0 ..< states.count, id: \.self) { index in
                let title = switch index {
                case 0: "Selected"
                case 1: "Unselected"
                case 2: "Disabled selected"
                default: "Disabled unselected"
                }

                Toggle(title, isOn: index < 2 ? $states[index] : .constant(index == 2))
                    .toggleStyle(CustomCheckboxToggleStyle())
                    .disabled(index >= 2)
            }
        }
        .padding()
    }
}
