//
//  MainWindowView.swift
//  Latest
//
//  Created by Claude Code on 16.09.25.
//  Copyright © 2025 Max Langer. All rights reserved.
//

import SwiftUI
import Cocoa
import Observation

/// The main SwiftUI window view that replaces the storyboard-based main window
struct MainWindowView: View {
    @ObservedObject var viewModel: MainWindowViewModel
    @State private var selectedApp: App?
    
    var body: some View {
        HSplitView {
            // Update List Pane
            updateListPane
                .frame(minWidth: 300, idealWidth: 400, maxWidth: .infinity)
            
            // Release Notes Pane
            releaseNotesPane
                .frame(minWidth: 300, idealWidth: 500, maxWidth: .infinity)
        }
        .frame(minWidth: 800, idealWidth: 1200, maxHeight: .infinity)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                toolbarItems
            }
        }
        .navigationTitle(Bundle.main.localizedInfoDictionary?[kCFBundleNameKey as String] as? String ?? "Latest")
        .navigationSubtitle("")
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }
    
    // MARK: - Update List Pane
    
    private var updateListPane: some View {
        VStack(spacing: 0) {
            updateListContainer
        }
        .background(Color(.controlBackgroundColor))
    }
    
    private var updateListContainer: some View {
        UpdateListContainer(
            viewModel: UpdateListViewModel(appListViewModel: viewModel.appListViewModel),
            onSelectionChanged: { app in
                selectedApp = app
            },
            onCheckForUpdates: {
                viewModel.reload()
            }
        )
    }
    
    // MARK: - Release Notes Pane
    
    private var releaseNotesPane: some View {
        VStack(spacing: 0) {
            if let app = selectedApp {
                ReleaseNotesContainer(app: app)
            } else {
                emptyReleaseNotesView
            }
        }
        .background(Color(.controlBackgroundColor))
    }
    
    private var emptyReleaseNotesView: some View {
        VStack {
            Spacer()
            
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("Select an app to view release notes")
                .font(.title2)
                .foregroundColor(.secondary)
                .padding(.top, 16)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Toolbar Items
    
    @ViewBuilder
    private var toolbarItems: some View {
        // Progress Indicator
        ProgressIndicatorView(state: viewModel.progressState)
        
        // Update All Button
        Button(action: {
            viewModel.updateAll()
        }) {
            Label("Update All", systemImage: "arrow.down.circle")
        }
        .disabled(!viewModel.isUpdateAllAvailable)
        
        // Reload Button
        Button(action: {
            viewModel.reload()
        }) {
            Label("Reload", systemImage: "arrow.clockwise")
        }
        .disabled(!viewModel.isReloadEnabled)
    }
}

// MARK: - Progress Indicator Component

struct ProgressIndicatorView: View {
    let state: MainWindowViewModel.ProgressState
    
    var body: some View {
        switch state {
        case .hidden:
            EmptyView()
        case .indeterminate:
            ProgressView()
                .scaleEffect(0.8)
                .progressViewStyle(CircularProgressViewStyle())
        case .determinate(let total, let completed):
            ProgressView(value: Double(completed), total: Double(total))
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 120)
        }
    }
}

// MARK: - Release Notes Container

struct ReleaseNotesContainer: View {
    let app: App
    @StateObject private var viewModel = ReleaseNotesSwiftUIViewModel()
    
    var body: some View {
        ReleaseNotesView(viewModel: viewModel)
            .onAppear {
                viewModel.loadReleaseNotes(for: app)
            }
            .onChange(of: app) { _, newApp in
                viewModel.loadReleaseNotes(for: newApp)
            }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("MainWindowView") {
    MainWindowView(viewModel: MainWindowViewModel())
        .frame(width: 1200, height: 800)
}
#endif