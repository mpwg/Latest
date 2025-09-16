//
//  GeneralSettingsViewController.swift
//  Latest
//
//  Created by Max Langer on 27.12.24.
//  Copyright © 2024 Max Langer. All rights reserved.
//

import SwiftUI

/// SwiftUI backing for the General settings tab.
struct GeneralSettingsView: View {
    @StateObject private var settings = AppListSettingsObserver()

    var body: some View {
        Form {
            Section {
                Text("General Settings")
                    .font(.headline)
                    .padding(.bottom, 8)
            }

            Section {
                SettingsToggleRow(
                    title: "Include apps with limited support",
                    description: "Update information is generally available but may sometimes be outdated or inaccurate. Updates cannot be performed directly here.",
                    isOn: settings.includeLimitedBinding
                )

                SettingsToggleRow(
                    title: "Include unsupported apps",
                    description: "Apps that can't be updated automatically by Latest, such as apps without integrated update mechanisms.",
                    isOn: settings.includeUnsupportedBinding
                )
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Reusable toggle row component for settings
private struct SettingsToggleRow: View {
    let title: String
    let description: String
    let isOn: Binding<Bool>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(title, isOn: isOn)
                .toggleStyle(.switch)

            Text(description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.leading, 20)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

/// Bridges the existing observable settings into an `ObservableObject` for SwiftUI.
final class AppListSettingsObserver: ObservableObject, Observer {
    let id = UUID()
    
    @Published private(set) var includeAppsWithLimitedSupport: Bool
    @Published private(set) var includeUnsupportedApps: Bool
    
    init() {
        includeAppsWithLimitedSupport = AppListSettings.shared.includeAppsWithLimitedSupport
        includeUnsupportedApps = AppListSettings.shared.includeUnsupportedApps
        
        AppListSettings.shared.add(self) { [weak self] in
            guard let self else { return }
            self.includeAppsWithLimitedSupport = AppListSettings.shared.includeAppsWithLimitedSupport
            self.includeUnsupportedApps = AppListSettings.shared.includeUnsupportedApps
        }
    }
    
    deinit {
        AppListSettings.shared.remove(self)
    }
    
    var includeLimitedBinding: Binding<Bool> {
        Binding(get: { [weak self] in
            self?.includeAppsWithLimitedSupport ?? false
        }, set: { [weak self] newValue in
            guard AppListSettings.shared.includeAppsWithLimitedSupport != newValue else { return }
            self?.includeAppsWithLimitedSupport = newValue
            AppListSettings.shared.includeAppsWithLimitedSupport = newValue
        })
    }
    
    var includeUnsupportedBinding: Binding<Bool> {
        Binding(get: { [weak self] in
            self?.includeUnsupportedApps ?? false
        }, set: { [weak self] newValue in
            guard AppListSettings.shared.includeUnsupportedApps != newValue else { return }
            self?.includeUnsupportedApps = newValue
            AppListSettings.shared.includeUnsupportedApps = newValue
        })
    }
}

