//
//  PathPickerView.swift
//  PocketPrefs
//
//  Optimized path selection with cached validation
//

import SwiftUI
import UniformTypeIdentifiers

struct PathPickerView: View {
    @Binding var paths: [String]
    @ObservedObject var manager: CustomAppManager
    @State private var showingPicker = false
    @State private var editingPathIndex: Int?
    @State private var editingPathText = ""
    @State private var pathSelectionType: PathSelectionType = .directory
    @StateObject private var pathValidator = PathValidator()
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
                        showingPicker = true
                    }) {
                        Label(NSLocalizedString("Settings_Add_Directory", comment: ""),
                              systemImage: "folder.badge.plus")
                    }
                    
                    Button(action: {
                        pathSelectionType = .file
                        showingPicker = true
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
                    LazyVStack(spacing: 8) {
                        ForEach(Array(paths.enumerated()), id: \.offset) { index, path in
                            PathItemView(
                                path: path,
                                validation: pathValidator.validate(path),
                                onEdit: { startEditing(index: index, path: path) },
                                onRemove: {
                                    paths.remove(at: index)
                                    pathValidator.invalidate(path)
                                },
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
            isPresented: $showingPicker,
            allowedContentTypes: pathSelectionType == .directory
                ? [.folder]
                : [.data, .text, .json, .xml, .propertyList, .plainText, .sourceCode, .item],
            allowsMultipleSelection: false,
        ) { result in
            handleFileSelection(result)
        }
        .sheet(item: $editingPathIndex) { _ in
            PathEditSheet(
                pathText: $editingPathText,
                onSave: {
                    if let index = editingPathIndex {
                        if index == -1 {
                            if !editingPathText.isEmpty, !paths.contains(editingPathText) {
                                paths.append(editingPathText)
                            }
                        } else {
                            pathValidator.invalidate(paths[index])
                            paths[index] = editingPathText
                        }
                    }
                    editingPathIndex = nil
                },
                onCancel: { editingPathIndex = nil },
            )
        }
        .onChange(of: paths) { _, newPaths in
            pathValidator.validateBatch(newPaths)
        }
        .onAppear {
            pathValidator.validateBatch(paths)
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
        editingPathIndex = -1
        editingPathText = ""
    }
}

// MARK: - Path Validator

@MainActor
final class PathValidator: ObservableObject {
    private var cache: [String: PathValidation] = [:]
    
    struct PathValidation {
        let exists: Bool
        let type: PathType
    }
    
    enum PathType {
        case file, directory, unknown
        
        var icon: String {
            switch self {
            case .file: "doc.fill"
            case .directory: "folder.fill"
            case .unknown: "questionmark.circle"
            }
        }
    }
    
    func validate(_ path: String) -> PathValidation {
        if let cached = cache[path] {
            return cached
        }
        
        let expandedPath = NSString(string: path).expandingTildeInPath
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory)
        
        let type: PathType = exists ? (isDirectory.boolValue ? .directory : .file) : .unknown
        let validation = PathValidation(exists: exists, type: type)
        
        cache[path] = validation
        return validation
    }
    
    func validateBatch(_ paths: [String]) {
        for path in paths where cache[path] == nil {
            _ = validate(path)
        }
    }
    
    func invalidate(_ path: String) {
        cache.removeValue(forKey: path)
    }
}

// MARK: - Path Item View

struct PathItemView: View {
    let path: String
    let validation: PathValidator.PathValidation
    let onEdit: () -> Void
    let onRemove: () -> Void
    
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: validation.type.icon)
                .font(.system(size: 14))
                .foregroundColor(validation.exists ? Color.App.accent.color(for: colorScheme) : Color.App.warning.color(for: colorScheme))
            
            Text(path)
                .font(DesignConstants.Typography.body)
                .foregroundColor(validation.exists ? Color.App.primary.color(for: colorScheme) : Color.App.secondary.color(for: colorScheme))
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
            }
            
            if !validation.exists {
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
                .fill(Color.App.secondaryBackground.color(for: colorScheme).opacity(0.5)),
        )
        .onHover { hovering in
            isHovered = hovering
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

// Extension for sheet binding
extension Int: @retroactive Identifiable {
    public var id: Int { self }
}
