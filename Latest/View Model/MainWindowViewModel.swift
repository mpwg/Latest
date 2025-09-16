//
//  MainWindowViewModel.swift
//  Latest
//
//  Created by ChatGPT on 2024-XX-XX.
//

import Foundation

/// Coordinates window-level behavior independently from the AppKit implementation.
final class MainWindowViewModel: NSObject, Observer, UpdateCheckProgressReporting {
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

    var onProgressStateChange: ((ProgressState) -> Void)?
    var onReloadAvailabilityChange: ((Bool) -> Void)?
    var onUpdateAllAvailabilityChange: ((Bool) -> Void)?
    var onMenuStateChange: ((MenuState) -> Void)?

    private let coordinator: UpdateCheckCoordinator
    private var isObserving = false
    private var isReloadEnabled = true {
        didSet {
            guard oldValue != isReloadEnabled else { return }
            onReloadAvailabilityChange?(isReloadEnabled)
        }
    }
    private var progressState: ProgressState = .hidden {
        didSet {
            guard oldValue != progressState else { return }
            onProgressStateChange?(progressState)
        }
    }
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

    func menuState() -> MenuState {
        MenuState(sortOrder: AppListSettings.shared.sortOrder,
                  showInstalledUpdates: AppListSettings.shared.showInstalledUpdates,
                  showIgnoredUpdates: AppListSettings.shared.showIgnoredUpdates,
                  sortOptions: AppListSettings.SortOptions.allCases)
    }

    private func notifyUpdateAvailability() {
        onUpdateAllAvailabilityChange?(hasUpdatesAvailable())
    }

    private func notifyMenuState() {
        onMenuStateChange?(menuState())
    }

    // MARK: - UpdateCheckProgressReporting

    func updateCheckerDidStartScanningForApps(_ updateChecker: UpdateCheckCoordinator) {
        isReloadEnabled = false
        progressState = .indeterminate
    }

    func updateChecker(_ updateChecker: UpdateCheckCoordinator, didStartCheckingApps numberOfApps: Int) {
        totalChecks = max(numberOfApps - 1, 0)
        completedChecks = 0
        progressState = .determinate(total: totalChecks, completed: completedChecks)
    }

    func updateChecker(_ updateChecker: UpdateCheckCoordinator, didCheckApp: App) {
        guard case .determinate(let total, _) = progressState else {
            return
        }
        completedChecks = min(completedChecks + 1, max(total, 0))
        progressState = .determinate(total: total, completed: completedChecks)
    }

    func updateCheckerDidFinishCheckingForUpdates(_ updateChecker: UpdateCheckCoordinator) {
        isReloadEnabled = true
        progressState = .hidden
        notifyUpdateAvailability()
    }
}
