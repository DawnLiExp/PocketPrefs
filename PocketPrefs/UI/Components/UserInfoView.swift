//
//  UserInfoView.swift
//  PocketPrefs
//
//  User information display component
//

import OpenDirectory
import SwiftUI

struct UserInfoView: View {
    @State private var userName: String = ""
    @State private var userAvatar: NSImage?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 8) {
            if !userName.isEmpty {
                Text(userName)
                    .font(.custom("HelveticaNeue-Thin", size: 22))
                    .foregroundColor(Color.App.secondary.color(for: colorScheme))
            }
            
            if let avatar = userAvatar {
                Image(nsImage: avatar)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 38, height: 38)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                Color.App.lightSeparator.color(for: colorScheme).opacity(0.6),
                                lineWidth: 1.5
                            )
                    )
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 38))
                    .foregroundColor(Color.App.secondary.color(for: colorScheme).opacity(1.6))
            }
        }
        .task {
            await loadUserInfo()
        }
    }
    
    // MARK: - User Info Loading
    
    private func loadUserInfo() async {
        do {
            let session = ODSession.default()
            let node = try ODNode(session: session, type: UInt32(kODNodeTypeLocalNodes))
            let record = try node.record(
                withRecordType: kODRecordTypeUsers,
                name: NSUserName(),
                attributes: [
                    "dsAttrTypeStandard:RealName",
                    kODAttributeTypeJPEGPhoto
                ]
            )
            
            // Extract first name
            if let realName = (try? record.values(forAttribute: "dsAttrTypeStandard:RealName") as? [String])?.first {
                userName = realName.components(separatedBy: " ").first ?? realName
            }
            
            // Extract and resize avatar
            if let dataList = try? record.values(forAttribute: kODAttributeTypeJPEGPhoto) as? [Data],
               let data = dataList.first,
               let image = NSImage(data: data)
            {
                userAvatar = resizeImage(image, to: NSSize(width: 38, height: 38))
            }
        } catch {
            // Fallback to system username if OpenDirectory fails
            userName = NSFullUserName().components(separatedBy: " ").first ?? ""
        }
    }
    
    private func resizeImage(_ image: NSImage, to targetSize: NSSize) -> NSImage {
        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        resized.unlockFocus()
        return resized
    }
}

// MARK: - Preview

#Preview {
    UserInfoView()
        .padding()
}
