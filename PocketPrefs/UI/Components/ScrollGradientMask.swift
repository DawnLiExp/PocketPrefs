//
//  ScrollGradientMask.swift
//  PocketPrefs
//
//  Modern scroll indicator using gradient masks - FINAL WORKING VERSION
//

import SwiftUI

// MARK: - Scroll Gradient Container

struct ScrollGradientContainer<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    @ViewBuilder let content: Content
    
    @State private var showTopGradient = false
    @State private var showBottomGradient = true
    @State private var contentHeight: CGFloat = 0
    @State private var containerHeight: CGFloat = 0
    
    private let gradientHeight: CGFloat = 18
    private let coordinateSpace = "scrollGradient"
    
    var body: some View {
        GeometryReader { containerProxy in
            ScrollViewReader { _ in
                ScrollView(showsIndicators: false) {
                    content
                        .background(
                            GeometryReader { geometry in
                                let frame = geometry.frame(in: .named(coordinateSpace))
                                Color.clear
                                    .onAppear {
                                        contentHeight = geometry.size.height
                                        containerHeight = containerProxy.size.height
                                    }
                                    .onChange(of: geometry.size.height) { _, newHeight in
                                        contentHeight = newHeight
                                    }
                                    .onChange(of: frame) { _, newFrame in
                                        updateGradients(offset: newFrame.minY)
                                    }
                            }
                        )
                }
                .coordinateSpace(name: coordinateSpace)
                .onAppear {
                    containerHeight = containerProxy.size.height
                }
                .overlay(alignment: .top) {
                    topGradient
                }
                .overlay(alignment: .bottom) {
                    bottomGradient
                }
            }
        }
    }
    
    private var topGradient: some View {
        LinearGradient(
            colors: [
                Color.App.contentAreaBackground.color(for: colorScheme),
                Color.App.contentAreaBackground.color(for: colorScheme).opacity(0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: gradientHeight)
        .opacity(showTopGradient ? 1 : 0)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.2), value: showTopGradient)
    }
    
    private var bottomGradient: some View {
        LinearGradient(
            colors: [
                Color.App.contentAreaBackground.color(for: colorScheme).opacity(0),
                Color.App.contentAreaBackground.color(for: colorScheme)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: gradientHeight)
        .opacity(showBottomGradient ? 1 : 0)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.2), value: showBottomGradient)
    }
    
    private func updateGradients(offset: CGFloat) {
        let threshold: CGFloat = 10
        
        showTopGradient = offset < -threshold
        
        if contentHeight > containerHeight {
            let maxScrollOffset = -(contentHeight - containerHeight)
        
            let isNearBottom = offset <= maxScrollOffset + threshold
            showBottomGradient = !isNearBottom
        } else {
            showBottomGradient = false
        }
    }
}
