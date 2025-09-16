//
//  SwiftUIMainWindowController.swift
//  Latest
//
//  Created by Claude Code on 16.09.25.
//  Copyright © 2025 Max Langer. All rights reserved.
//

import AppKit
import SwiftUI

/**
 A lightweight SwiftUI-based window controller that replaces the storyboard MainWindowController.
 This controller hosts the SwiftUI MainWindowView and manages window-level behaviors.
 */
class SwiftUIMainWindowController: NSWindowController, NSMenuItemValidation, NSMenuDelegate {
    
    /// Encapsulates the main window items with their according tag identifiers
    private enum MainMenuItem: Int {
        case latest = 0, file, edit, view, window, help
    }
    
    private let viewModel = MainWindowViewModel()
    private var hostingController: NSHostingController<MainWindowView>?
    
    // MARK: - Initialization
    
    convenience init() {
        // Create the window programmatically
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        self.init(window: window)
        setupWindow()
        setupContent()
    }
    
    // MARK: - Setup
    
    private func setupWindow() {
        guard let window = window else { return }
        
        // Window appearance
        window.titlebarAppearsTransparent = true
        window.title = Bundle.main.localizedInfoDictionary?[kCFBundleNameKey as String] as? String ?? "Latest"
        
        // Toolbar style
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .unified
        } else {
            window.titleVisibility = .hidden
        }
        
        // Window sizing and behavior
        window.setFrameAutosaveName("MainWindow")
        window.minSize = NSSize(width: 800, height: 600)
        window.center()
        
        // Set delegate
        window.delegate = self
    }
    
    private func setupContent() {
        guard let window = window else { return }
        
        // Create SwiftUI view with shared viewModel
        let contentView = MainWindowView(viewModel: viewModel)
        
        // Create hosting controller
        let hostingController = NSHostingController(rootView: contentView)
        self.hostingController = hostingController
        
        // Set as window's content
        window.contentViewController = hostingController
        
        // Setup menu delegate
        NSApplication.shared.mainMenu?.item(at: MainMenuItem.view.rawValue)?.submenu?.delegate = self
        
        // Start the view model
        viewModel.start()
        
        // Make window first responder and visible
        window.makeKeyAndOrderFront(self)
        window.makeFirstResponder(hostingController.view)
        
        // Trigger initial update check
        viewModel.reload()
    }
    
    // MARK: - Window Lifecycle
    
    override func windowDidLoad() {
        super.windowDidLoad()
        // Additional setup if needed
    }
    
    // MARK: - Action Methods
    
    /// Reloads the list / checks for updates
    @IBAction func reload(_ sender: Any?) {
        viewModel.reload()
    }
    
    /// Open all apps that have an update available
    @IBAction func updateAll(_ sender: Any?) {
        viewModel.updateAll()
    }
    
    @IBAction func performFindPanelAction(_ sender: Any?) {
        // Focus search field in SwiftUI view
        // This might need to be implemented through a binding or notification
        window?.makeFirstResponder(hostingController?.view)
    }
    
    @IBAction func visitWebsite(_ sender: NSMenuItem?) {
        NSWorkspace.shared.open(URL(string: "https://max.codes/latest")!)
    }
    
    @IBAction func donate(_ sender: NSMenuItem?) {
        NSWorkspace.shared.open(URL(string: "https://max.codes/latest/donate/")!)
    }
    
    // MARK: - Menu Item Validation
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let action = menuItem.action else {
            return true
        }
        
        switch action {
        case #selector(updateAll(_:)):
            return viewModel.hasUpdatesAvailable()
        case #selector(reload(_:)):
            return viewModel.isReloadEnabled
        case #selector(performFindPanelAction(_:)):
            // Only allow the find item
            return menuItem.tag == 1
        default:
            return true
        }
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        let menuState = viewModel.menuState
        
        menu.items.forEach { menuItem in
            // Sort By menu constructed dynamically
            if menuItem.identifier == NSUserInterfaceItemIdentifier(rawValue: "sortByMenu") {
                menuItem.submenu?.items = sortByMenuItems(using: menuState)
            }
            
            guard let action = menuItem.action else { return }
            
            switch action {
            case #selector(toggleShowInstalledUpdates(_:)):
                menuItem.state = menuState.showInstalledUpdates ? .on : .off
            case #selector(toggleShowIgnoredUpdates(_:)):
                menuItem.state = menuState.showIgnoredUpdates ? .on : .off
            default:
                ()
            }
        }
    }
    
    private func sortByMenuItems(using menuState: MainWindowViewModel.MenuState) -> [NSMenuItem] {
        menuState.sortOptions.map { order in
            let item = NSMenuItem(title: order.displayName, action: #selector(changeSortOrder), keyEquivalent: "")
            item.representedObject = order
            item.state = menuState.sortOrder == order ? .on : .off
            item.target = self
            
            return item
        }
    }
    
    // MARK: - Menu Actions
    
    @IBAction func changeSortOrder(_ sender: NSMenuItem?) {
        guard let order = sender?.representedObject as? AppListSettings.SortOptions else { return }
        viewModel.changeSortOrder(to: order)
    }
    
    @IBAction func toggleShowInstalledUpdates(_ sender: NSMenuItem?) {
        viewModel.toggleShowInstalledUpdates()
    }
    
    @IBAction func toggleShowIgnoredUpdates(_ sender: NSMenuItem?) {
        viewModel.toggleShowIgnoredUpdates()
    }
    
    deinit {
        viewModel.stop()
    }
}

// MARK: - NSWindowDelegate

extension SwiftUIMainWindowController: NSWindowDelegate {
    
    @available(macOS, deprecated: 11.0)
    func window(_ window: NSWindow, willPositionSheet sheet: NSWindow, using rect: NSRect) -> NSRect {
        // Always position sheets at the top of the window, ignoring toolbar insets
        return NSRect(x: rect.minX, y: window.frame.height, width: rect.width, height: rect.height)
    }
}