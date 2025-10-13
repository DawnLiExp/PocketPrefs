//
//  FadeInScaleAnimation.swift
//  PocketPrefs
//
//  Created by Manus on 2025/10/12.
//

import SwiftUI

struct FadeInScaleAnimation: ViewModifier {
    @State private var isAnimating: Bool = false

    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? 1 : 0)
            .scaleEffect(isAnimating ? 1 : 0.8)
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {
                    isAnimating = true
                }
            }
    }
}

extension View {
    func fadeInScaleAnimation() -> some View {
        modifier(FadeInScaleAnimation())
    }
}
