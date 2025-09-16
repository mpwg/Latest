//
//  AppDirectoryViewController.swift
//  Latest
//
//  Created by Max Langer on 29.02.24.
//  Copyright © 2024 Max Langer. All rights reserved.
//

import SwiftUI
import AppKit

/// SwiftUI backing for the locations settings tab.
struct LocationsSettingsView: View {
    @StateObject private var directoryStore = AppDirectoryStore()
    @State private var selection: URL?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localizedMain("ivV-VN-4CO.title"))
                .font(.headline)
            
            List(directoryStore.displayedURLs, id: \.self, selection: $selection) { url in
                DirectoryRowView(url: url)
                    .tag(url)
            }
            .frame(minHeight: 200)
            .listStyle(.inset)
            
            HStack(spacing: 12) {
                Button(action: presentOpenPanel) {
                    Label(localizedMain("SettingsLocationsAdd"), systemImage: "plus")
                }
                
                Button(action: removeSelected) {
                    Label(localizedMain("SettingsLocationsRemove"), systemImage: "minus")
                }
                .disabled(!canRemoveSelection)
                
                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private var canRemoveSelection: Bool {
        guard let selection else { return false }
        return directoryStore.canRemove(selection)
    }
    
    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        
        let completion: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK else { return }
            panel.urls.forEach(directoryStore.add)
            selection = panel.urls.last
        }
        
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(panel.runModal())
        }
    }
    
    private func removeSelected() {
        guard let selection, canRemoveSelection else { return }
        directoryStore.remove(selection)
        self.selection = nil
    }
}

private func localizedMain(_ key: String) -> String {
    String(localized: .init(key), table: "Main", bundle: .main)
}
