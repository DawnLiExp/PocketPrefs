//
//  SlideInAnimation.swift
//  PocketPrefs
//
//  Created by Manus on 2025/10/12.
//

import SwiftUI

struct SlideInAnimation: ViewModifier {
    @State private var isAnimating: Bool = false

    func body(content: Content) -> some View {
        content
            .offset(y: isAnimating ? 0 : 50)
            .opacity(isAnimating ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {
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
