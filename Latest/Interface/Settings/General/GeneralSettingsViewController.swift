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
        VStack(alignment: .leading, spacing: 16) {
            Text("General Settings")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Include apps with limited support", isOn: settings.includeLimitedBinding)
                Text("Update information is generally available but may sometimes be outdated or inaccurate. Updates cannot be performed directly here.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Include unsupported apps", isOn: settings.includeUnsupportedBinding)
                Text("Apps that can't be updated automatically by Latest, such as apps without integrated update mechanisms.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }
            
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

