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
    @Environment(\.isEnabled) private var isEnabled

    /// Adaptive border color based on enabled state and current color scheme.
    /// Uses secondary text color with reduced opacity for subtle appearance.
    private var strokeColor: Color {
        guard isEnabled else { return .primary.opacity(0.2) }
        return Color.App.secondary.color(for: colorScheme).opacity(0.6)
    }

    /// Adaptive checkmark color utilizing the application's accent color.
    /// Automatically degrades to reduced opacity when disabled.
    private var checkmarkColor: Color {
        guard isEnabled else { return .primary.opacity(0.3) }
        return Color.App.accent.color(for: colorScheme)
    }

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .center, spacing: 8) {
                // Checkbox visual container with animated state transitions
                ZStack {
                    // Consistent border frame using design system corner radius
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(strokeColor, lineWidth: 1.5)
                        .frame(width: 15, height: 15)

                    // Conditionally rendered checkmark with smooth transitions
                    if configuration.isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(checkmarkColor)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
                .animation(.smooth(duration: 0.15), value: configuration.isOn)

                configuration.label
            }
            .contentShape(Rectangle()) // Extends hit testing area to full HStack bounds
        }
        .buttonStyle(PlainButtonStyle()) // Removes default button visual effects
        .disabled(!isEnabled)
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
