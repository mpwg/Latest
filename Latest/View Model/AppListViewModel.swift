//
//  AppListViewModel.swift
//  Latest
//
//  Created by ChatGPT on 2024-XX-XX.
//

import Foundation

/// Provides the state for rendering the app list independent from the view layer.
final class AppListViewModel: NSObject, Observer {
    struct Status {
        /// User-visible description of the current update count.
        let statusText: String
        /// Dock badge value when updates are available.
        let badgeValue: String?
        /// Whether at least one update can be triggered from Latest.
        let hasUpdates: Bool
    }

    var id = UUID()

    var onSnapshotChange: ((AppListSnapshot, Bool) -> Void)?
    var onStatusChange: ((Status) -> Void)?

    private let coordinator: UpdateCheckCoordinator
    private var apps: [App] = []
    private(set) var snapshot: AppListSnapshot
    private(set) var currentStatus: Status
    private var isObserving = false

    init(coordinator: UpdateCheckCoordinator = .shared) {
        self.coordinator = coordinator
        self.snapshot = AppListSnapshot(withApps: [], filterQuery: nil)
        self.currentStatus = Status(statusText: Self.statusText(for: 0), badgeValue: nil, hasUpdates: false)
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

        AppListSettings.shared.add(self) { [weak self] in
            self?.handleSettingsChange()
        }

        coordinator.appProvider.addObserver(self) { [weak self] apps in
            guard let self = self else { return }
            self.apps = apps
            self.refreshSnapshot(animated: true)
        }

        deliverCurrentState()
    }

    func stop() {
        guard isObserving else { return }
        isObserving = false

        AppListSettings.shared.remove(self)
        coordinator.appProvider.removeObserver(self)
    }

    func deliverCurrentState() {
        onSnapshotChange?(snapshot, false)
        onStatusChange?(currentStatus)
    }

    func setFilter(query: String?) {
        let normalizedQuery = query?.isEmpty == false ? query : nil
        guard normalizedQuery != snapshot.filterQuery else { return }

        let updatedSnapshot = AppListSnapshot(withApps: apps, filterQuery: normalizedQuery)
        applySnapshot(updatedSnapshot, animated: false)
    }

    func checkForUpdates() {
        coordinator.run()
    }

    func performUpdate(on app: App) {
        DispatchQueue.main.async {
            app.performUpdate()
        }
    }

    func setIgnored(_ ignored: Bool, for app: App) {
        coordinator.appProvider.setIgnoredState(ignored, for: app)
    }

    func open(_ app: App) {
        app.open()
    }

    func revealInFinder(_ app: App) {
        app.showInFinder()
    }

    func app(at index: Int) -> App? {
        guard index >= 0 && index < snapshot.entries.count else {
            return nil
        }
        return snapshot.app(at: index)
    }

    private func refreshSnapshot(animated: Bool) {
        let updatedSnapshot = AppListSnapshot(withApps: apps, filterQuery: snapshot.filterQuery)
        applySnapshot(updatedSnapshot, animated: animated)
    }

    private func applySnapshot(_ newSnapshot: AppListSnapshot, animated: Bool) {
        snapshot = newSnapshot
        onSnapshotChange?(newSnapshot, animated)
        updateStatus()
    }

    private func handleSettingsChange() {
        refreshSnapshot(animated: true)
    }

    private func updateStatus() {
        let includeExternal = AppListSettings.shared.includeAppsWithLimitedSupport
        let count = coordinator.appProvider.countOfAvailableUpdates { includeExternal || $0.usesBuiltInUpdater }
        let badgeFormatter = NumberFormatter()
        let badgeValue = count == 0 ? nil : badgeFormatter.string(from: NSNumber(value: count))
        let hasUpdates = !coordinator.appProvider.updatableApps.isEmpty

        currentStatus = Status(statusText: Self.statusText(for: count), badgeValue: badgeValue, hasUpdates: hasUpdates)
        onStatusChange?(currentStatus)
    }

    private static func statusText(for count: Int) -> String {
        let format = NSLocalizedString("NumberOfUpdatesAvailable", comment: "number of updates available")
        return String.localizedStringWithFormat(format, count)
    }
}
