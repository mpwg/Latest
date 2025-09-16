//
//  AppDelegate.swift
//  Latest
//
//  Created by Max Langer on 15.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//


import SwiftUI

@main
struct LatestApp: SwiftUI.App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var mainViewModel = MainWindowViewModel()

    var body: some Scene {
        WindowGroup("Latest") {
            MainWindowView(viewModel: mainViewModel)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    SettingsWindowManager.shared.openSettings()
                }
                .keyboardShortcut(",")
            }
        }

        Settings {
            SettingsView()
        }
    }
}

// Supporting AppDelegate for additional functionality
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Additional setup if needed
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
	
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Always terminate the app if the main window is closed
        return true
    }
    
    @IBAction func showSettings(_ sender: Any?) {
        SettingsWindowManager.shared.openSettings()
    }
}
