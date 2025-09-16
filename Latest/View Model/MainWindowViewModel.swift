//
//  MainWindowViewModel.swift
//  Latest
//
//  Created by ChatGPT on 2024-XX-XX.
//

import Foundation
import Combine

/// Coordinates window-level behavior independently from the AppKit implementation.
final class MainWindowViewModel: NSObject, ObservableObject, Observer, UpdateCheckProgressReporting {
    enum ProgressState: Equatable {
        case hidden
        case indeterminate
        case determinate(total: Int, completed: Int)
    }

    struct MenuState {
        let sortOrder: AppListSettings.SortOptions
        let showInstalledUpdates: Bool
        let showIgnoredUpdates: Bool
        let sortOptions: [AppListSettings.SortOptions]
    }

    var id = UUID()

    let appListViewModel: AppListViewModel

    // Published properties for SwiftUI
    @Published var progressState: ProgressState = .hidden
    @Published var isReloadEnabled: Bool = true
    @Published var isUpdateAllAvailable: Bool = false
    @Published var menuState: MenuState = MenuState(
        sortOrder: .name,
        showInstalledUpdates: false,
        showIgnoredUpdates: false,
        sortOptions: AppListSettings.SortOptions.allCases
    )
    
    // Legacy callback-based properties for AppKit compatibility
    var onProgressStateChange: ((ProgressState) -> Void)? {
        didSet {
            // Call immediately with current state
            onProgressStateChange?(progressState)
        }
    }
    var onReloadAvailabilityChange: ((Bool) -> Void)? {
        didSet {
            // Call immediately with current state
            onReloadAvailabilityChange?(isReloadEnabled)
        }
    }
    var onUpdateAllAvailabilityChange: ((Bool) -> Void)? {
        didSet {
            // Call immediately with current state
            onUpdateAllAvailabilityChange?(isUpdateAllAvailable)
        }
    }
    var onMenuStateChange: ((MenuState) -> Void)? {
        didSet {
            // Call immediately with current state
            onMenuStateChange?(menuState)
        }
    }

    private let coordinator: UpdateCheckCoordinator
    private var isObserving = false
    private var totalChecks = 0
    private var completedChecks = 0

    init(appListViewModel: AppListViewModel = AppListViewModel(), coordinator: UpdateCheckCoordinator = .shared) {
        self.appListViewModel = appListViewModel
        self.coordinator = coordinator
        super.init()
    }

    deinit {
        stop()
    }

    func start() {
        guard !isObserving else {
            deliverCurrentState()
            return
        }

        isObserving = true
        appListViewModel.start()

        AppListSettings.shared.add(self) { [weak self] in
            self?.notifyMenuState()
        }

        coordinator.progressDelegate = self
        coordinator.appProvider.addObserver(self) { [weak self] _ in
            self?.notifyUpdateAvailability()
        }

        deliverCurrentState()
        
        // Start initial update check
        coordinator.run()
    }

    func stop() {
        guard isObserving else { return }
        isObserving = false

        appListViewModel.stop()
        if coordinator.progressDelegate === self {
            coordinator.progressDelegate = nil
        }
        coordinator.appProvider.removeObserver(self)
        AppListSettings.shared.remove(self)
    }

    func deliverCurrentState() {
        onReloadAvailabilityChange?(isReloadEnabled)
        onProgressStateChange?(progressState)
        notifyUpdateAvailability()
        notifyMenuState()
    }

    func reload() {
        appListViewModel.checkForUpdates()
    }

    func updateAll() {
        coordinator.appProvider.updatableApps.forEach { app in
            guard !app.isUpdating else { return }
            app.performUpdate()
        }
    }

    func hasUpdatesAvailable() -> Bool {
        return !coordinator.appProvider.updatableApps.isEmpty
    }

    func changeSortOrder(to order: AppListSettings.SortOptions) {
        AppListSettings.shared.sortOrder = order
    }

    func toggleShowInstalledUpdates() {
        AppListSettings.shared.showInstalledUpdates.toggle()
    }

    func toggleShowIgnoredUpdates() {
        AppListSettings.shared.showIgnoredUpdates.toggle()
    }

    private func currentMenuState() -> MenuState {
        MenuState(sortOrder: AppListSettings.shared.sortOrder,
                  showInstalledUpdates: AppListSettings.shared.showInstalledUpdates,
                  showIgnoredUpdates: AppListSettings.shared.showIgnoredUpdates,
                  sortOptions: AppListSettings.SortOptions.allCases)
    }

    private func notifyUpdateAvailability() {
        let hasUpdates = hasUpdatesAvailable()
        isUpdateAllAvailable = hasUpdates
        onUpdateAllAvailabilityChange?(hasUpdates)
    }

    private func notifyMenuState() {
        let currentState = currentMenuState()
        menuState = currentState
        onMenuStateChange?(currentState)
    }

    // MARK: - UpdateCheckProgressReporting

    func updateCheckerDidStartScanningForApps(_ updateChecker: UpdateCheckCoordinator) {
        isReloadEnabled = false
        progressState = .indeterminate
        onReloadAvailabilityChange?(isReloadEnabled)
        onProgressStateChange?(progressState)
    }

    func updateChecker(_ updateChecker: UpdateCheckCoordinator, didStartCheckingApps numberOfApps: Int) {
        totalChecks = max(numberOfApps - 1, 0)
        completedChecks = 0
        progressState = .determinate(total: totalChecks, completed: completedChecks)
        onProgressStateChange?(progressState)
    }

    func updateChecker(_ updateChecker: UpdateCheckCoordinator, didCheckApp: App) {
        guard case .determinate(let total, _) = progressState else {
            return
        }
        completedChecks = min(completedChecks + 1, max(total, 0))
        progressState = .determinate(total: total, completed: completedChecks)
        onProgressStateChange?(progressState)
    }

    func updateCheckerDidFinishCheckingForUpdates(_ updateChecker: UpdateCheckCoordinator) {
        isReloadEnabled = true
        progressState = .hidden
        onReloadAvailabilityChange?(isReloadEnabled)
        onProgressStateChange?(progressState)
        notifyUpdateAvailability()
    }
}
