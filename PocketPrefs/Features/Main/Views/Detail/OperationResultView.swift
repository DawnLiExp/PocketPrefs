import SwiftUI

struct OperationResultView: View {
    let result: OperationSummary
    let onDone: () -> Void

    private var title: String {
        switch result.status {
        case .success: String(localized: "Operation_Result_Success")
        case .partialFailure: String(localized: "Operation_Result_Partial")
        case .failure: String(localized: "Operation_Result_Failure")
        case .notPerformed: String(localized: "Operation_Result_Not_Performed")
        }
    }

    private var symbol: String {
        switch result.status {
        case .success: "checkmark.circle.fill"
        case .partialFailure: "exclamationmark.triangle.fill"
        case .failure: "xmark.circle.fill"
        case .notPerformed: "info.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 30))
                    .foregroundStyle(result.status == .success ? Color.green : Color.primary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(DesignConstants.Typography.title)
                    Text(result.kind == .backup
                         ? String(localized: "MainView_Mode_Backup")
                         : String(localized: "MainView_Mode_Restore"))
                        .foregroundStyle(.secondary)
                }
            }
            Text(String(localized: "Operation_Result_Counts", defaultValue: "Succeeded \(result.successCount) / Total \(result.totalProcessed)"))
                .font(DesignConstants.Typography.body)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let notice = result.notice {
                        Text(notice)
                    } else if result.status == .notPerformed {
                        Text("Operation_Result_No_Selection")
                    }
                    ForEach(result.failures.indices, id: \.self) { index in
                        let failure = result.failures[index]
                        VStack(alignment: .leading, spacing: 5) {
                            Text(failure.name).font(DesignConstants.Typography.headline)
                            Text(failure.reason).font(DesignConstants.Typography.body)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .cardEffect()
                        .accessibilityElement(children: .combine)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }
            HStack {
                Spacer()
                Button("Operation_Result_Done", action: onDone)
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
