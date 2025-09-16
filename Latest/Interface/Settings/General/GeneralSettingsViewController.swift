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
            Text(localizedMain("Aeb-LJ-TzL.title"))
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Toggle(localizedMain("Ntm-I4-heJ.title"), isOn: settings.includeLimitedBinding)
                Text(localizedMain("rG3-x9-kec.title"))
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Toggle(localizedMain("HfB-8a-u7P.title"), isOn: settings.includeUnsupportedBinding)
                Text(localizedMain("Mdn-MF-57Q.title"))
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

private func localizedMain(_ key: String) -> String {
    String(localized: .init(key), table: "Main", bundle: .main)
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

