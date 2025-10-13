//
//  BreathingPulseAnimation.swift
//  PocketPrefs
//
//  Created by Manus on 2025/10/12.
//

import SwiftUI

struct BreathingPulseAnimation: ViewModifier {
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                ) {
                    scale = 1.05
                }
            }
    }
}

extension View {
    func breathingPulseAnimation() -> some View {
        modifier(BreathingPulseAnimation())
    }
}
