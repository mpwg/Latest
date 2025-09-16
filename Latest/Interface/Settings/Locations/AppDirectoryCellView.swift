//
//  AppDirectoryCellView.swift
//  Latest
//
//  Created by Max Langer on 29.02.24.
//  Copyright © 2024 Max Langer. All rights reserved.
//

import SwiftUI
import AppKit

/// Row representing a directory that Latest scans for apps.
struct DirectoryRowView: View {
    let url: URL
    
    @State private var icon: NSImage = DirectoryRowView.defaultFolderIcon
    @State private var appCountText: String?
    @State private var isReachable = true
    @State private var isLoading = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
            
            Text(url.relativePath)
                .font(.body)
                .foregroundColor(isReachable ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if let appCountText {
                Text(appCountText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .task(id: url) {
            await refresh()
        }
    }
    
    @MainActor
    private func refresh() async {
        isLoading = true
        let reachable = (try? url.checkResourceIsReachable()) == true
        let icon = reachable ? NSWorkspace.shared.icon(forFile: url.path) : DirectoryRowView.warningIcon
        var countText: String?
        if reachable {
            let count = await Task.detached(priority: .utility) { () -> Int in
                BundleCollector.collectBundles(at: url).count
            }.value
            countText = NumberFormatter.localizedString(from: NSNumber(value: count), number: .none)
        }
        
        withAnimation(.default) {
            self.isReachable = reachable
            self.icon = icon
            self.appCountText = countText
            self.isLoading = false
        }
    }
    
    private static var defaultFolderIcon: NSImage {
        NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericFolderIcon)))
    }
    
    private static var warningIcon: NSImage {
        if #available(macOS 11.0, *) {
            return NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil) ?? defaultFolderIcon
        } else {
            return NSImage(named: NSImage.cautionName) ?? defaultFolderIcon
        }
    }
}
