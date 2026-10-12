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
                    AppListRow(row: row, fontScale: model.preferences.fontScale, selected: model.selectedID == row.id).tag(row.id)
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
        .font(.system(size: 14 * model.preferences.fontScale))
        .controlSize(model.preferences.fontScale >= 1.3 ? .large : .regular)
        .onReceive(NotificationCenter.default.publisher(for: .latestFocusSearch)) { _ in searchFocused = true }
        .onChange(of: model.externalURL) { _, url in
            if let url { NSWorkspace.shared.open(url); model.externalURL = nil }
        }
        .toolbar {
            ToolbarItem { NativeSourcePicker(selection: $model.sourceFilter, scale: model.preferences.fontScale) }
            ToolbarItem { Button("Check for Updates", systemImage: "arrow.clockwise") { model.refresh() }.disabled(model.scanning).accessibilityIdentifier("refresh") }
            ToolbarItem { Button("Update All", systemImage: "square.and.arrow.down") { model.updateAll() }
                .disabled(model.scanning || model.activeUpdates > 0 || !model.hasBulkUpdates).accessibilityIdentifier("update-all") }
            ToolbarItem { Button("Settings…", systemImage: "gear") { showSettings() }.accessibilityIdentifier("settings") }
        }
        .alert("Update Failed", isPresented: $model.showingError) {
            Button("Show Diagnostics in Finder") { NSWorkspace.shared.activateFileViewerSelecting([model.diagnosticURL]) }
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
    let selected: Bool
    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: row.icon).resizable().frame(width: 36, height: 36).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(row.record.app.name).font(.system(size: 14 * fontScale, weight: .medium))
                Text(row.record.app.version.description).font(.system(size: 12 * fontScale)).foregroundStyle(.secondary)
                StatusTitle(status: row.record.status).font(.system(size: 12 * fontScale))
                    .foregroundStyle(selected ? AnyShapeStyle(.primary) : row.record.status == .available ? AnyShapeStyle(.blue) : AnyShapeStyle(.secondary))
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
                Text(LocalizedStringResource("Checking %lld of %lld", defaultValue: "Checking \(model.checked) of \(model.total)")).font(.system(size: 12 * model.preferences.fontScale))
            } else {
                Text(LocalizedStringResource("%lld apps", defaultValue: "\(model.visibleRows.count) apps")).font(.system(size: 12 * model.preferences.fontScale))
            }
            if !model.warnings.isEmpty { Text(model.warnings.joined(separator: "\n")).font(.system(size: 12 * model.preferences.fontScale)).foregroundStyle(.orange).accessibilityIdentifier("inventory-warnings") }
        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(.bar)
    }
}

/// Native controls own keyboard/AX behavior; the adapter only forwards selection.
struct NativeSegmentedChoice<Value: Equatable>: NSViewRepresentable {
    @Binding var selection: Value
    let options: [(Value, LocalizedStringResource)]
    let label: LocalizedStringResource
    let identifier: String
    let scale: Double

    func makeCoordinator() -> Coordinator { Coordinator(selection: $selection, values: options.map(\.0)) }
    func makeNSView(context: Context) -> NSSegmentedControl {
        NSSegmentedControl(labels: options.map { String(localized: $0.1) }, trackingMode: .selectOne,
                           target: context.coordinator, action: #selector(Coordinator.select(_:)))
    }
    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.selection = $selection
        context.coordinator.values = options.map(\.0)
        for (index, option) in options.enumerated() {
            let title = String(localized: option.1)
            if control.label(forSegment: index) != title { control.setLabel(title, forSegment: index) }
        }
        let selected = options.firstIndex { $0.0 == selection } ?? -1
        // Preserve native keyboard focus when scans re-render unchanged selection.
        if control.selectedSegment != selected { control.selectedSegment = selected }
        let size = CGFloat(14 * scale)
        if control.font?.pointSize != size { control.font = .systemFont(ofSize: size) }
        let controlSize: NSControl.ControlSize = scale >= 1.3 ? .large : .regular
        if control.controlSize != controlSize { control.controlSize = controlSize }
        if control.isEnabled != context.environment.isEnabled { control.isEnabled = context.environment.isEnabled }
        control.setAccessibilityLabel(String(localized: label))
        control.setAccessibilityIdentifier(identifier)
    }
    @MainActor final class Coordinator: NSObject {
        var selection: Binding<Value>
        var values: [Value]
        init(selection: Binding<Value>, values: [Value]) { self.selection = selection; self.values = values }
        @objc func select(_ control: NSSegmentedControl) {
            guard values.indices.contains(control.selectedSegment) else { return }
            selection.wrappedValue = values[control.selectedSegment]
        }
    }
}

private struct NativeSourcePicker: NSViewRepresentable {
    @Binding var selection: UpdateSource?
    let scale: Double
    private var values: [UpdateSource?] { [nil] + UpdateSource.allCases.map(Optional.some) }
    func makeCoordinator() -> Coordinator { Coordinator(selection: $selection, values: values) }
    func makeNSView(context: Context) -> NSPopUpButton {
        let control = NSPopUpButton(frame: .zero, pullsDown: false)
        control.addItem(withTitle: String(localized: "All Sources"))
        for source in UpdateSource.allCases { control.addItem(withTitle: String(localized: source.interfaceTitle)) }
        control.target = context.coordinator; control.action = #selector(Coordinator.select(_:))
        return control
    }
    func updateNSView(_ control: NSPopUpButton, context: Context) {
        context.coordinator.selection = $selection
        let selected = values.firstIndex(of: selection) ?? 0
        if control.indexOfSelectedItem != selected { control.selectItem(at: selected) }
        let size = CGFloat(14 * scale)
        if control.font?.pointSize != size {
            control.font = .systemFont(ofSize: size)
            control.menu?.font = control.font
        }
        let controlSize: NSControl.ControlSize = scale >= 1.3 ? .large : .regular
        if control.controlSize != controlSize { control.controlSize = controlSize }
        if control.isEnabled != context.environment.isEnabled { control.isEnabled = context.environment.isEnabled }
        control.setAccessibilityLabel(String(localized: "Source"))
        control.setAccessibilityIdentifier("source-filter")
    }
    @MainActor final class Coordinator: NSObject {
        var selection: Binding<UpdateSource?>
        let values: [UpdateSource?]
        init(selection: Binding<UpdateSource?>, values: [UpdateSource?]) { self.selection = selection; self.values = values }
        @objc func select(_ control: NSPopUpButton) {
            guard values.indices.contains(control.indexOfSelectedItem) else { return }
            selection.wrappedValue = values[control.indexOfSelectedItem]
        }
    }
}

extension UpdateSource {
    var interfaceTitle: LocalizedStringResource {
        switch self {
        case .appStore: "App Store"
        case .homebrew: "Homebrew"
        case .sparkle: "Sparkle"
        case .catalogue: "Catalogue Hint"
        case .unknown: "Unknown Source"
        }
    }
}
struct SourceTitle: View {
    let source: UpdateSource
    var body: some View { Text(source.interfaceTitle) }
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
