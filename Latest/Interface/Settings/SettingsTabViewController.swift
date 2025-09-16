//
//  SettingsTabViewController.swift
//  Latest
//
//  Created by Max Langer on 27.12.24.
//  Copyright © 2024 Max Langer. All rights reserved.
//

import SwiftUI
import AppKit

/// The tabs that are available in the settings window.
private enum SettingsTab: Hashable {
    case general
    case locations
}

/// Root view for the settings window implemented in SwiftUI.
private struct SettingsView: View {
    @State private var selection: SettingsTab = .general
    
    var body: some View {
        settingsContent
            .frame(minWidth: 460, minHeight: 320)
    }
    
    @ViewBuilder
    private var settingsContent: some View {
            tabView.tabViewStyle(.automatic)
    }
    
    private var tabView: some View {
        TabView(selection: $selection) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(SettingsTab.general)
            
            LocationsSettingsView()
                .tabItem {
                    Label("Locations", systemImage: "externaldrive")
                }
                .tag(SettingsTab.locations)
        }
    }
}

/// Window controller presenting the SwiftUI-based settings window.
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()
    
    private init() {
        let hostingController = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = NSLocalizedString("Settings", comment: "Settings window title")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.toolbarStyle = .unified
        window.setContentSize(NSSize(width: 460, height: 340))
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(sender)
    }
}

