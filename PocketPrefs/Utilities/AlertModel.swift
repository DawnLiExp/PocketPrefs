//
//  AlertModel.swift
//  PocketPrefs
//
//  Shared alert model and SwiftUI binding helper.
//

import Foundation
import SwiftUI

/// Common alert data model that drives SwiftUI `.alert` rendering.
///
/// Precondition: `primaryAction` must be called on MainActor.
/// `bindAlert(_:)` guarantees this via `Task { @MainActor in ... }` bridge.
struct AlertModel: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let primaryLabel: String
    let style: Style
    let primaryAction: @MainActor () -> Void
    var secondaryLabel: String = .init(localized: "Common_Cancel")

    enum Style: Equatable {
        case destructive
        case confirm
        case info
    }

    @MainActor
    static func info(title: String, message: String) -> AlertModel {
        AlertModel(
            title: title,
            message: message,
            primaryLabel: "OK",
            style: .info,
            primaryAction: {}
        )
    }
}

extension AlertModel.Style {
    var primaryButtonRole: ButtonRole? {
        self == .destructive ? .destructive : nil
    }
}

extension View {
    /// Binds and renders a standard alert from `AlertModel`.
    func bindAlert(_ alert: Binding<AlertModel?>) -> some View {
        self.alert(
            alert.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { alert.wrappedValue != nil },
                set: { if !$0 { alert.wrappedValue = nil } }
            ),
            presenting: alert.wrappedValue
        ) { model in
            Button(model.primaryLabel, role: model.style.primaryButtonRole) {
                Task { @MainActor in
                    model.primaryAction()
                }
            }

            if model.style != .info {
                Button(model.secondaryLabel, role: .cancel) {}
            }
        } message: { model in
            Text(model.message)
        }
    }
}
