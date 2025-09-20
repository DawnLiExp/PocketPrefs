//
//  PathPickerView.swift
//  PocketPrefs
//
//  Path selection and management component
//

import SwiftUI
import UniformTypeIdentifiers

struct PathPickerView: View {
    @Binding var paths: [String]
    @ObservedObject var manager: CustomAppManager
    @State private var showingFilePicker = false
    @State private var showingFolderPicker = false
    @State private var editingPathIndex: Int?
    @State private var editingPathText = ""
    @State private var pathSelectionType: PathSelectionType = .directory
    @Environment(\.colorScheme) var colorScheme
    
    enum PathSelectionType {
        case file
        case directory
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label(NSLocalizedString("Settings_Config_Paths", comment: ""),
                      systemImage: "folder.badge.gearshape")
                    .font(DesignConstants.Typography.headline)
                    .foregroundColor(Color.App.primary.color(for: colorScheme))
                
                Spacer()
                
                // Add path menu
                Menu {
                    Button(action: {
                        pathSelectionType = .directory
                        showingFolderPicker = true
                    }) {
                        Label(NSLocalizedString("Settings_Add_Directory", comment: ""),
                              systemImage: "folder.badge.plus")
                    }
                    
                    Button(action: {
                        pathSelectionType = .file
                        showingFilePicker = true
                    }) {
                        Label(NSLocalizedString("Settings_Add_File", comment: ""),
                              systemImage: "doc.badge.plus")
                    }
                    
                    Divider()
                    
                    Button(action: addManualPath) {
                        Label(NSLocalizedString("Settings_Add_Path_Manually", comment: ""),
                              systemImage: "text.cursor")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(LinearGradient.appAccent(for: colorScheme))
                }
                .menuStyle(.borderlessButton)
            }
            
            // Paths list
            if paths.isEmpty {
                EmptyPathsView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(paths.enumerated()), id: \.offset) { index, path in
                            PathItemView(
                                path: path,
                                index: index,
                                manager: manager,
                                onEdit: { startEditing(index: index, path: path) },
                                onRemove: { paths.remove(at: index) }
                            )
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color.App.tertiaryBackground.color(for: colorScheme).opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: DesignConstants.Layout.smallCornerRadius))
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.data, .text, .json, .xml, .propertyList, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .sheet(item: $editingPathIndex) { _ in
            PathEditSheet(
                pathText: $editingPathText,
                onSave: {
                    if let index = editingPathIndex {
                        paths[index] = editingPathText
                    }
                    editingPathIndex = nil
                },
                onCancel: { editingPathIndex = nil }
            )
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                let path = url.path
                let homePath = NSHomeDirectory()
                let displayPath = path.hasPrefix(homePath)
                    ? "~" + path.dropFirst(homePath.count)
                    : path
                
                if !paths.contains(displayPath) {
                    paths.append(displayPath)
                }
            }
        case .failure(let error):
            print("File selection error: \(error)")
        }
    }
    
    private func startEditing(index: Int, path: String) {
        editingPathIndex = index
        editingPathText = path
    }
    
    private func addManualPath() {
        editingPathIndex = -1 // Special value for new path
        editingPathText = ""
        
        // Create a temporary sheet for adding new path
        DispatchQueue.main.async {
            if !editingPathText.isEmpty, !paths.contains(editingPathText) {
                paths.append(editingPathText)
            }
        }
    }
}

// MARK: - Path Item View

struct PathItemView: View {
    let path: String
    let index: Int
    let manager: CustomAppManager
    let onEdit: () -> Void
    let onRemove: () -> Void
    
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    
    var pathType: CustomAppManager.PathType {
        manager.getPathType(path)
    }
    
    var pathExists: Bool {
        manager.pathExists(path)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: pathType.icon)
                .font(.system(size: 14))
                .foregroundColor(pathExists ? Color.App.accent.color(for: colorScheme) : Color.App.warning.color(for: colorScheme))
            
            Text(path)
                .font(DesignConstants.Typography.body)
                .foregroundColor(pathExists ? Color.App.primary.color(for: colorScheme) : Color.App.secondary.color(for: colorScheme))
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            if isHovered {
                HStack(spacing: 4) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.App.accent.color(for: colorScheme))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.App.error.color(for: colorScheme))
                    }
                    .buttonStyle(.plain)
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            if !pathExists {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color.App.warning.color(for: colorScheme))
                    .help(NSLocalizedString("Settings_Path_Not_Found", comment: ""))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.App.secondaryBackground.color(for: colorScheme).opacity(0.5))
        )
        .onHover { hovering in
            withAnimation(DesignConstants.Animation.quick) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Empty Paths View

struct EmptyPathsView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 32))
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
            
            Text(NSLocalizedString("Settings_No_Paths_Added", comment: ""))
                .font(DesignConstants.Typography.body)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
            
            Text(NSLocalizedString("Settings_Add_Path_Hint", comment: ""))
                .font(DesignConstants.Typography.caption)
                .foregroundColor(Color.App.secondary.color(for: colorScheme))
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Path Edit Sheet

struct PathEditSheet: View {
    @Binding var pathText: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            Text(NSLocalizedString("Settings_Edit_Path", comment: ""))
                .font(DesignConstants.Typography.title)
            
            TextField(NSLocalizedString("Settings_Path_Placeholder", comment: ""),
                      text: $pathText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 400)
            
            HStack(spacing: 12) {
                Button(NSLocalizedString("Common_Cancel", comment: ""), action: onCancel)
                    .buttonStyle(SecondaryButtonStyle())
                
                Button(NSLocalizedString("Common_Save", comment: ""), action: onSave)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(pathText.isEmpty)
            }
        }
        .padding(30)
        .frame(width: 500)
        .background(Color.App.secondaryBackground.color(for: colorScheme))
    }
}

// Extension to make Int conform to Identifiable for sheet binding
extension Int: @retroactive Identifiable {
    public var id: Int { self }
}
