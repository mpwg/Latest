//
//  SettingsTabViewController.swift
//  Latest
//
//  Created by Max Langer on 27.12.24.
//  Copyright © 2024 Max Langer. All rights reserved.
//

import SwiftUI

/// The tabs that are available in the settings window.
private enum SettingsTab: Hashable {
    case general
    case locations
}

/// Root view for the settings window implemented in pure SwiftUI.
struct SettingsView: View {
    @State private var selection: SettingsTab = .general

    var body: some View {
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
        .tabViewStyle(.automatic)
        .frame(minWidth: 460, minHeight: 320)
    }
}

/// Pure SwiftUI settings window manager using environment-based approach.
final class SettingsWindowManager: ObservableObject {
    static let shared = SettingsWindowManager()

    private init() {}

    /// Opens the settings window using SwiftUI's Settings scene.
    func openSettings() {
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            // Fallback for older macOS versions
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}

