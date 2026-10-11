import SwiftUI
import LatestApplication
import AppKit
import LatestCore

extension Notification.Name {
    static let latestFocusSearch = Notification.Name("LatestFocusSearch")
}

struct LatestWindow: View {
    @Bindable var model: AppModel
    let showSettings: () -> Void
    @FocusState private var searchFocused: Bool
    var body: some View {
        NavigationSplitView {
            List(selection: $model.selectedID) {
                ForEach(model.visibleRows) { row in
                    AppListRow(row: row, fontScale: model.preferences.fontScale).tag(row.id)
                        .contextMenu {
                            Button("Open App") { NSWorkspace.shared.open(row.id.url) }
                            Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([row.id.url]) }
                            Button { model.ignore(row.id) } label: {
                                if model.preferences.ignoredBundleIDs.contains(row.record.app.bundleID) { Text("Stop Ignoring") }
                                else { Text("Ignore App") }
                            }
                            Button("Skip This Version") { model.skip(row.id) }.disabled(row.record.candidate == nil)
                            Button("Clear Skipped Version") { model.clearSkip(row.id) }
                        }
                }
            }
            .accessibilityIdentifier("app-list")
            .searchable(text: $model.query, prompt: "Search apps")
            .searchFocused($searchFocused)
            .navigationTitle("Applications")
            .navigationSplitViewColumnWidth(min: 300, ideal: 380)
            .safeAreaInset(edge: .bottom) { InventoryFooter(model: model) }
        } detail: {
            if let row = model.selectedRow { AppDetail(row: row, model: model).id(row.id) }
            else { ContentUnavailableView("Select an App", systemImage: "app.dashed", description: Text("Choose an app to inspect its update source and release notes.")) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .latestFocusSearch)) { _ in searchFocused = true }
        .onChange(of: model.externalURL) { _, url in
            if let url { NSWorkspace.shared.open(url); model.externalURL = nil }
        }
        .toolbar {
            ToolbarItem { Picker("Source", selection: $model.sourceFilter) {
                Text("All Sources").tag(Optional<UpdateSource>.none)
                ForEach(UpdateSource.allCases, id: \.rawValue) { source in SourceTitle(source: source).tag(Optional(source)) }
            }.accessibilityLabel(Text("Source")).accessibilityIdentifier("source-filter") }
            ToolbarItem { Button("Check for Updates", systemImage: "arrow.clockwise") { model.refresh() }.disabled(model.scanning).accessibilityIdentifier("refresh") }
            ToolbarItem { Button("Update All", systemImage: "square.and.arrow.down") { model.updateAll() }
                .disabled(model.scanning || model.activeUpdates > 0 || !model.hasBulkUpdates).accessibilityIdentifier("update-all") }
            ToolbarItem { Button("Settings…", systemImage: "gear") { showSettings() }.accessibilityIdentifier("settings") }
        }
        .alert("Update Failed", isPresented: $model.showingError) {
            Button("Open Diagnostics") { NSWorkspace.shared.activateFileViewerSelecting([model.diagnosticURL]) }
            Button("OK", role: .cancel) {}
        } message: { Text(model.errorMessage) }
        .confirmationDialog("Confirm Major Upgrade", isPresented: $model.confirmingMajor, titleVisibility: .visible) {
            Button("Install Major Upgrade") { model.confirmMajor() }.disabled(model.scanning)
            Button("Cancel", role: .cancel) { model.cancelMajor() }
        } message: { Text("A major upgrade may require a new licence or change compatibility. Review the release notes before continuing.") }
    }
}

private struct AppListRow: View {
    let row: AppRow
    let fontScale: Double
    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: row.icon).resizable().frame(width: 36, height: 36).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(row.record.app.name).font(.system(size: 14 * fontScale, weight: .medium))
                Text(row.record.app.version.description).font(.system(size: 12 * fontScale)).foregroundStyle(.secondary)
                StatusTitle(status: row.record.status).font(.caption).foregroundStyle(row.record.status == .available ? .blue : .secondary)
            }
            Spacer()
            if let event = row.event, !event.isTerminal { ProgressView().controlSize(.small) }
        }.padding(.vertical, 5)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("app-row-" + row.record.app.bundleID)
        .accessibilityValue(row.id.path)
    }
}

private struct InventoryFooter: View {
    let model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.scanning {
                ProgressView(value: Double(model.checked), total: Double(max(1, model.total)))
                Text(LocalizedStringResource("Checking %lld of %lld", defaultValue: "Checking \(model.checked) of \(model.total)")).font(.caption)
            } else {
                Text(LocalizedStringResource("%lld apps", defaultValue: "\(model.visibleRows.count) apps")).font(.caption)
            }
            if !model.warnings.isEmpty { Text(model.warnings.joined(separator: "\n")).font(.caption).foregroundStyle(.orange).accessibilityIdentifier("inventory-warnings") }
        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(.bar)
    }
}

struct SourceTitle: View {
    let source: UpdateSource
    var body: some View {
        switch source {
        case .appStore: Text("App Store")
        case .homebrew: Text("Homebrew")
        case .sparkle: Text("Sparkle")
        case .catalogue: Text("Catalogue Hint")
        case .unknown: Text("Unknown Source")
        }
    }
}
struct StatusTitle: View {
    let status: AppStatus
    var body: some View {
        switch status {
        case .available: Text("Update Available")
        case .current: Text("Up to Date")
        case .external: Text("Update Externally")
        case .unknown: Text("Status Unknown")
        case .incompatible: Text("Incompatible Update")
        case .ignored: Text("Ignored")
        case .skipped: Text("Version Skipped")
        }
    }
}
