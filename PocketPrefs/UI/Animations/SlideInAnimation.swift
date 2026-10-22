//
//  SlideInAnimation.swift
//  PocketPrefs
//
//  Created by Manus on 2025/10/12.
//

import SwiftUI

struct SlideInAnimation: ViewModifier {
    @State private var isAnimating: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(y: reduceMotion || isAnimating ? 0 : 8)
            .opacity(isAnimating ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.18)) {
                    isAnimating = true
                }
            }
    }
}

extension View {
    func slideInAnimation() -> some View {
        modifier(SlideInAnimation())
    }
}
