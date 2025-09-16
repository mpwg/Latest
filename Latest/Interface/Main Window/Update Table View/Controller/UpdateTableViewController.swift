//
//  UpdateTableViewController.swift (SwiftUI Implementation)
//  Latest
//
//  Rebuilt with SwiftUI by Claude Code on 16.09.25.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa
import SwiftUI
import Combine
import Foundation

// MARK: - SwiftUI Models

@Observable
class UpdateListRowModel: NSObject, Identifiable {
    let id = UUID()
    let app: App
    var isUpdating: Bool = false
    var updateProgress: Double = 0.0
    var updateError: Error?

    init(app: App) {
        self.app = app
        super.init()
        self.setupUpdateObservation()
    }

    func highlightedName(filterQuery: String?) -> AttributedString {
        var attributedString = AttributedString(app.name)

        if let filterQuery = filterQuery, !filterQuery.isEmpty {
            let range = app.name.range(of: filterQuery, options: .caseInsensitive)
            if let range = range {
                let nsRange = NSRange(range, in: app.name)
                let attributedRange = Range(nsRange, in: attributedString)

                if let attributedRange = attributedRange {
                    attributedString[attributedRange].backgroundColor = .yellow.opacity(0.3)
                }
            }
        }

        return attributedString
    }

    var versionText: String? {
        if let version = app.version.versionNumber,
           let newVersion = app.remoteVersion?.versionNumber {
            return "\(version) → \(newVersion)"
        } else if let version = app.version.versionNumber {
            return version
        }
        return nil
    }

    private func setupUpdateObservation() {
        UpdateQueue.shared.addObserver(self, to: app.identifier) { [weak self] progress in
            DispatchQueue.main.async {
                self?.updateProgress(with: progress)
            }
        }
    }

    private func updateProgress(with state: UpdateOperation.ProgressState) {
        switch state {
        case .none:
            isUpdating = false
            updateProgress = 0.0
            updateError = nil
        case .pending, .initializing, .installing, .cancelling:
            isUpdating = true
        case .downloading(let loadedSize, let totalSize):
            isUpdating = true
            updateProgress = (Double(loadedSize) / Double(totalSize)) * 0.75
        case .extracting(let progressValue):
            isUpdating = true
            updateProgress = 0.75 + (progressValue * 0.25)
        case .error(let error):
            isUpdating = false
            updateError = error
        }
    }

    deinit {
        UpdateQueue.shared.removeObserver(self, for: app.identifier)
    }
}

@Observable
class UpdateListSectionModel: Identifiable {
    let id = UUID()
    let section: AppListSnapshot.Section
    var rows: [UpdateListRowModel]

    init(section: AppListSnapshot.Section, apps: [App]) {
        self.section = section
        self.rows = apps.map { UpdateListRowModel(app: $0) }
    }
}

@Observable
class UpdateListViewModel: ObservableObject {
    private let appListViewModel: AppListViewModel
    var sections: [UpdateListSectionModel] = []
    var selectedApp: App?
    var searchText: String = "" {
        didSet {
            appListViewModel.setFilter(query: searchText.isEmpty ? nil : searchText)
        }
    }

    var isEmpty: Bool {
        sections.isEmpty
    }

    var showPlaceholder: Bool {
        isEmpty && searchText.isEmpty
    }

    init(appListViewModel: AppListViewModel) {
        self.appListViewModel = appListViewModel
        setupBindings()
    }

    private func setupBindings() {
        appListViewModel.onSnapshotChange = { [weak self] snapshot, animated in
            DispatchQueue.main.async {
                self?.updateSections(from: snapshot)
            }
        }

        appListViewModel.start()
        appListViewModel.deliverCurrentState()
    }

    private func updateSections(from snapshot: AppListSnapshot) {
        var newSections: [UpdateListSectionModel] = []
        var currentSection: AppListSnapshot.Section?
        var currentApps: [App] = []

        for entry in snapshot.entries {
            switch entry {
            case .section(let section):
                // Save previous section if exists
                if let currentSection = currentSection {
                    newSections.append(UpdateListSectionModel(section: currentSection, apps: currentApps))
                }
                // Start new section
                currentSection = section
                currentApps = []

            case .app(let app):
                currentApps.append(app)
            }
        }

        // Add final section
        if let currentSection = currentSection {
            newSections.append(UpdateListSectionModel(section: currentSection, apps: currentApps))
        }

        sections = newSections
    }

    func selectApp(_ app: App?) {
        selectedApp = app
    }

    func checkForUpdates() {
        appListViewModel.checkForUpdates()
    }

    func performUpdate(on app: App) {
        appListViewModel.performUpdate(on: app)
    }

    func setIgnored(_ ignored: Bool, for app: App) {
        appListViewModel.setIgnored(ignored, for: app)
    }

    func open(_ app: App) {
        appListViewModel.open(app)
    }

    func revealInFinder(_ app: App) {
        appListViewModel.revealInFinder(app)
    }
}

// MARK: - SwiftUI Views

struct UpdateListRowView: View {
    @Bindable var rowModel: UpdateListRowModel
    let filterQuery: String?
    let isSelected: Bool
    let onAppTapped: (App) -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: nil) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                if let iconImage = iconForApp() {
                    Image(nsImage: iconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.controlBackgroundColor))
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(highlightedAppName())
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if let versionText = rowModel.versionText {
                    Text(versionText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if rowModel.app.isIgnored {
                Text("Ignored")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                SwiftUIUpdateButtonView(app: rowModel.app, showActionButton: true)
                    .frame(height: 21)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 65)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onAppTapped(rowModel.app)
        }
    }

    private func iconForApp() -> NSImage? {
        var icon: NSImage?
        IconCache.shared.icon(for: rowModel.app) { image in
            icon = image
        }
        return icon
    }

    private func highlightedAppName() -> AttributedString {
        rowModel.highlightedName(filterQuery: filterQuery)
    }
}

struct UpdateListSectionView: View {
    let section: AppListSnapshot.Section

    var body: some View {
        HStack {
            Text(section.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(height: 27)
        .background(Color(.controlBackgroundColor).opacity(0.5))
    }
}

struct UpdateListView: View {
    @Bindable var viewModel: UpdateListViewModel
    var onSelectionChanged: ((App?) -> Void)?

    var body: some View {
        ZStack {
            if viewModel.showPlaceholder {
                placeholderView
            } else {
                listView
            }
        }
        .background(Color(.controlBackgroundColor))
    }

    private var placeholderView: some View {
        VStack {
            Spacer()
            Text("No Updates Available")
                .font(.title2)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var listView: some View {
        List(selection: Binding(
            get: { viewModel.selectedApp?.identifier },
            set: { identifier in
                let app = viewModel.sections.flatMap(\.rows).first { $0.app.identifier == identifier }?.app
                viewModel.selectApp(app)
                onSelectionChanged?(app)
            }
        )) {
            ForEach(viewModel.sections) { sectionModel in
                Section {
                    ForEach(sectionModel.rows) { rowModel in
                        UpdateListRowView(
                            rowModel: rowModel,
                            filterQuery: viewModel.searchText.isEmpty ? nil : viewModel.searchText,
                            isSelected: viewModel.selectedApp?.identifier == rowModel.app.identifier,
                            onAppTapped: { app in
                                viewModel.selectApp(app)
                                onSelectionChanged?(app)
                            }
                        )
                        .tag(rowModel.app.identifier)
                        .contextMenu {
                            contextMenuContent(for: rowModel.app)
                        }
                    }
                } header: {
                    UpdateListSectionView(section: sectionModel.section)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.controlBackgroundColor))
    }

    @ViewBuilder
    private func contextMenuContent(for app: App) -> some View {
        if app.updateAvailable && !app.isUpdating {
            Button(updateTitle(for: app)) {
                viewModel.performUpdate(on: app)
            }
        }

        Button("Open") {
            viewModel.open(app)
        }

        Button("Show in Finder") {
            viewModel.revealInFinder(app)
        }

        Divider()

        if app.isIgnored {
            Button("Unignore") {
                viewModel.setIgnored(false, for: app)
            }
        } else {
            Button("Ignore") {
                viewModel.setIgnored(true, for: app)
            }
        }
    }

    private func updateTitle(for app: App) -> String {
        if let externalUpdater = app.externalUpdaterName {
            return String(format: NSLocalizedString("ExternalUpdateAction", comment: "Action to update a given app outside of Latest. The placeholder is filled with the name of the external updater. (App Store, App Name)"), externalUpdater)
        } else {
            return NSLocalizedString("UpdateAction", comment: "Action to update a given app.")
        }
    }
}

struct UpdateListContainer: View {
    @Bindable var viewModel: UpdateListViewModel
    var onSelectionChanged: ((App?) -> Void)?
    var onCheckForUpdates: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            UpdateListView(viewModel: viewModel) { app in
                onSelectionChanged?(app)
            }
        }
        .background(Color(.controlBackgroundColor))
        .onAppear {
            // Initial delivery of current state if needed
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 13))

            TextField("Search", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            if !viewModel.searchText.isEmpty {
                Button(action: {
                    viewModel.searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(.separatorColor), lineWidth: 0.5)
        )
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

// MARK: - Main View Controller

/**
 This is the class handling the update process and displaying its results using SwiftUI
 */
class UpdateTableViewController: NSViewController {

    private var hostingView: NSHostingView<UpdateListContainer>?
    private var updateListViewModel: UpdateListViewModel?

    /// The detail view controller that shows the release notes
    weak var releaseNotesViewController: ReleaseNotesViewController?

    /// The empty state label centered in the list view indicating that no updates are available
    @IBOutlet weak var placeholderLabel: NSTextField!

    /// The label indicating how many updates are available
    @IBOutlet weak var updatesLabel: NSTextField!

    /// The search field used for filtering apps
    @IBOutlet weak var searchField: NSSearchField!

    /// Provides the backing data for the list independent from the view implementation.
    var viewModel: AppListViewModel? {
        didSet {
            guard oldValue !== viewModel else { return }
            oldValue?.onSnapshotChange = nil
            oldValue?.onStatusChange = nil
            if isViewLoaded {
                setupSwiftUIView()
            }
        }
    }

    /// The last status emitted by the view model.
    private var currentStatus: AppListViewModel.Status?

    /// The currently selected app within the UI.
    var selectedApp: App? {
        didSet {
            updateListViewModel?.selectApp(selectedApp)
            releaseNotesViewController?.display(releaseNotesFor: selectedApp)
        }
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        if viewModel == nil {
            viewModel = AppListViewModel()
        }

        setupSwiftUIView()
        bindViewModel()

        if #available(macOS 11, *) {
            updatesLabel.isHidden = true
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        // Setup title
        if let status = currentStatus {
            apply(status: status)
        }

        // Setup search field constraint
        if let searchField = searchField {
            NSLayoutConstraint(
                item: searchField,
                attribute: .top,
                relatedBy: .equal,
                toItem: view.window?.contentLayoutGuide,
                attribute: .top,
                multiplier: 1.0,
                constant: 1
            ).isActive = true
        }

        view.window?.makeFirstResponder(nil)
    }

    // MARK: - Setup

    private func setupSwiftUIView() {
        guard let appListViewModel = viewModel else { return }

        // Create the SwiftUI view model
        updateListViewModel = UpdateListViewModel(appListViewModel: appListViewModel)

        guard let updateListViewModel = updateListViewModel else { return }

        // Create the SwiftUI view
        let container = UpdateListContainer(
            viewModel: updateListViewModel,
            onSelectionChanged: { [weak self] app in
                self?.selectedApp = app
            },
            onCheckForUpdates: { [weak self] in
                self?.checkForUpdates()
            }
        )

        // Remove existing hosting view
        hostingView?.removeFromSuperview()

        // Create new hosting view
        hostingView = NSHostingView(rootView: container)
        guard let hostingView = hostingView else { return }

        // Configure hosting view
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingView)

        // Set up constraints
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Hide old UI elements (now handled by SwiftUI)
        placeholderLabel?.isHidden = true
        searchField?.isHidden = true
    }

    private func bindViewModel() {
        guard let viewModel = viewModel else { return }

        viewModel.onStatusChange = { [weak self] status in
            DispatchQueue.main.async {
                self?.apply(status: status)
            }
        }

        viewModel.start()
        viewModel.deliverCurrentState()
    }

    // MARK: - Public Methods

    /// Triggers the update checking mechanism
    func checkForUpdates() {
        viewModel?.checkForUpdates()
        view.window?.makeFirstResponder(self)
    }

    /// Selects the app at the given index.
    func selectApp(at index: Int?) {
        // For backward compatibility, find the app by index if needed
        guard let index = index, index >= 0 else {
            selectedApp = nil
            return
        }

        let flatApps = updateListViewModel?.sections.flatMap { $0.rows.map { $0.app } } ?? []
        guard index < flatApps.count else { return }

        selectedApp = flatApps[index]
    }

    // MARK: - Interface Updating

    /// Updates the title in the toolbar ("No / n updates available") and the badge of the app icon
    private func apply(status: AppListViewModel.Status) {
        currentStatus = status
        NSApplication.shared.dockTile.badgeLabel = status.badgeValue

        if #available(macOS 11, *) {
            view.window?.subtitle = status.statusText
        } else {
            updatesLabel?.stringValue = status.statusText
        }
    }

    // MARK: - TouchBar Support

    override func makeTouchBar() -> NSTouchBar? {
        let touchBar = NSTouchBar()
        touchBar.defaultItemIdentifiers = []
        return touchBar
    }
}
