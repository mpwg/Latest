//
//  AppDirectoryViewController.swift
//  Latest
//
//  Created by Max Langer on 29.02.24.
//  Copyright © 2024 Max Langer. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

/// SwiftUI backing for the locations settings tab.
struct LocationsSettingsView: View {
    @StateObject private var directoryStore = AppDirectoryStore()
    @State private var selection: URL?
    @State private var isShowingFileImporter = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Locations")
                .font(.headline)

            Text("Latest will scan these directories for applications:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            List(directoryStore.directoryList, id: \.self, selection: $selection) { url in
                DirectoryRowView(url: url)
                    .tag(url)
            }
            .frame(minHeight: 200)
            .listStyle(.inset)
            .overlay(alignment: .center) {
                if directoryStore.directoryList.isEmpty {
                    ContentUnavailableView(
                        "No Locations",
                        systemImage: "externaldrive",
                        description: Text("Add directories to scan for applications")
                    )
                }
            }

            HStack(spacing: 12) {
                Button(action: { isShowingFileImporter = true }) {
                    Label("Add Location", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                Button(action: removeSelected) {
                    Label("Remove Location", systemImage: "minus")
                }
                .disabled(!canRemoveSelection)

                Spacer()

                if !directoryStore.directoryList.isEmpty {
                    Text("\(directoryStore.directoryList.count) location\(directoryStore.directoryList.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: true
        ) { result in
            handleFileImportResult(result)
        }
    }

    private var canRemoveSelection: Bool {
        guard let selection else { return false }
        return directoryStore.canRemove(selection)
    }

    private func removeSelected() {
        guard let selection, canRemoveSelection else { return }
        directoryStore.remove(selection)
        self.selection = nil
    }

    private func handleFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            urls.forEach { url in
                _ = url.startAccessingSecurityScopedResource()
                directoryStore.add(url)
                url.stopAccessingSecurityScopedResource()
            }
            selection = urls.last
        case .failure:
            // Handle error silently - the file picker already shows user-friendly errors
            break
        }
    }
}
