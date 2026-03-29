//
//  DualColumnSettingsLayout.swift
//  PocketPrefs
//
//  A reusable layout for dual-column settings panels (e.g., list + details).
//

import SwiftUI

struct DualColumnSettingsLayout<Left: View, Right: View>: View {
    let leftWidth: CGFloat
    @ViewBuilder let left: () -> Left
    @ViewBuilder let right: () -> Right

    var body: some View {
        HStack(spacing: 0) {
            left()
                .frame(width: leftWidth)
                .frame(maxHeight: .infinity)

            Divider()

            right()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
