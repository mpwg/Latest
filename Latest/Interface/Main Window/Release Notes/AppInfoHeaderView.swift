//
//  AppInfoHeaderView.swift
//  Latest
//
//  Created by AI Assistant on 16.09.25.
//  Copyright © 2025 Max Langer. All rights reserved.
//

import SwiftUI

struct AppInfoHeaderView: View {
    let app: App
    @State private var appIcon: NSImage?
    @State private var showingSupportStatus = false
    
    /// Date formatter used to display the app's update date
    private static let appDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        return dateFormatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // App Icon
                Group {
                    if let appIcon = appIcon {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.quaternary)
                            .overlay(
                                Image(systemName: "app.dashed")
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                .frame(width: 48, height: 48)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    // App Name
                    Text(app.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    // Version Information
                    if let versionInfo = app.localizedVersionInformation {
                        Text(versionInfo.combined(includeNew: app.updateAvailable))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Update Date
                    if let date = app.latestUpdateDate {
                        Text(Self.appDateFormatter.string(from: date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    // Update Button
                    SwiftUIUpdateButtonView(app: app)
                    
                    // External Update Label
                    if app.updateAvailable, let externalUpdaterName = app.externalUpdaterName {
                        Text(String(format: NSLocalizedString("ExternalUpdateActionWithAppName", comment: "An explanatory text indicating where the update will be performed. The placeholder will be filled with the name of the external updater (App Store, App Name). The text will appear below the Update button, so that it reads: \"Update in XY\""), externalUpdaterName))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Support Status Button (if enabled)
            if shouldShowSupportStatus {
                HStack {
                    Button(action: {
                        showingSupportStatus = true
                    }) {
                        HStack(spacing: 6) {
                            if let statusImage = app.source.supportState.statusImage {
                                Image(nsImage: statusImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)
                            }
                            
                            Text(app.source.supportState.compactLabel)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            loadAppIcon()
        }
        .onChange(of: app) { _, _ in
            loadAppIcon()
        }
        .sheet(isPresented: $showingSupportStatus) {
            SupportStatusInfoView(app: app)
        }
    }
    
    private var shouldShowSupportStatus: Bool {
        AppListSettings.shared.includeUnsupportedApps || AppListSettings.shared.includeAppsWithLimitedSupport
    }
    
    private func loadAppIcon() {
        IconCache.shared.icon(for: app) { icon in
            DispatchQueue.main.async {
                self.appIcon = icon
            }
        }
    }
}

// MARK: - Support Status Info View

struct SupportStatusInfoView: View {
    let app: App
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                if let statusImage = app.source.supportState.statusImage {
                    Image(nsImage: statusImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                }
                
                Text(app.source.supportState.label)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
            }
            
            // Description
            Text(supportStateDescription)
                .font(.body)
                .foregroundColor(.secondary)
            
            // Report Issue Button (only for full support)
            if case .full = app.source.supportState {
                Button("Report Issue") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/mangerlahn/Latest/issues")!)
                }
                .buttonStyle(.borderedProminent)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 400, height: 200)
    }
    
    private var supportStateDescription: String {
        switch app.source.supportState {
        case .none:
            return NSLocalizedString("NoSupportDescription", comment: "Description for apps without support.")
        case .limited:
            return NSLocalizedString("LimitedSupportDescription", comment: "Description for apps with limited support.")
        case .full:
            return NSLocalizedString("FullSupportDescription", comment: "Description for apps with full support.")
        }
    }
}