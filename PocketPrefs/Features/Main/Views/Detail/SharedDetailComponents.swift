//
//  SharedDetailComponents.swift
//  PocketPrefs
//
//  Shared components for detail views
//

import AppKit
import SwiftUI

// MARK: - AppDetailHeader

struct AppDetailHeader: View {
    let app: AppConfig
    let currentMode: MainView.AppMode
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: currentMode == .backup ? "arrow.up.circle" : "arrow.down.circle")
                    .font(.system(size: 24))
                    .foregroundColor(Color.App.accent.color(for: colorScheme))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name)
                        .font(DesignConstants.Typography.title)
                    
                    Text(app.bundleId)
                        .font(DesignConstants.Typography.caption)
                        .foregroundColor(Color.App.secondary.color(for: colorScheme))
                }
                
                Spacer()
                
                if currentMode == .backup {
                    if app.isInstalled {
                        StatusBadge(
                            text: NSLocalizedString("Detail_App_Status_Installed", comment: ""),
                            color: Color.App.success.color(for: colorScheme),
                        )
                    } else {
                        StatusBadge(
                            text: NSLocalizedString("Detail_App_Status_Not_Installed", comment: ""),
                            color: Color.App.warning.color(for: colorScheme),
                        )
                    }
                }
            }
            
            Text(String(format: NSLocalizedString("AppList_App_Config_Paths_Count", comment: ""), app.configPaths.count))
                .font(DesignConstants.Typography.body)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
        }
        .padding(20)
        .background(Color.App.contentAreaBackground.color(for: colorScheme))
    }
}

// MARK: - ConfigPathItem

struct ConfigPathItem: View {
    let path: String
    @State private var isHovered = false
    @State private var fileSize: String = "-"
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            Image(systemName: "folder")
                .font(.system(size: 14))
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(path)
                    .font(DesignConstants.Typography.body)
                    .foregroundColor(Color.App.primary.color(for: colorScheme))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Text(fileSize)
                    .font(DesignConstants.Typography.caption)
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }
            
            Spacer()
            
            Button(action: showInFinder) {
                Image(systemName: "magnifyingglass.circle")
                    .font(.system(size: 16))
                    .foregroundColor(
                        isHovered
                            ? Color.App.primary.color(for: colorScheme)
                            : Color.App.secondary.color(for: colorScheme),
                    )
            }
            .buttonStyle(.plain)
            .help(NSLocalizedString("Show_In_Finder", comment: ""))
        }
        .padding(12)
        .cardEffect(isSelected: false)
        .onHover { hovering in
            withAnimation(DesignConstants.Animation.quick) {
                isHovered = hovering
            }
        }
        .task {
            fileSize = await FileOperationService.shared.calculateFileSize(at: path)
        }
    }
    
    private func showInFinder() {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        
        if FileManager.default.fileExists(atPath: expandedPath) {
            NSWorkspace.shared.selectFile(
                expandedPath,
                inFileViewerRootedAtPath: url.deletingLastPathComponent().path,
            )
        } else {
            let parentURL = url.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: parentURL.path) {
                NSWorkspace.shared.open(parentURL)
            }
        }
    }
}
