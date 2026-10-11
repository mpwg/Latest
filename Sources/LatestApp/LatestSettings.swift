import AppKit
import SwiftUI
import LatestApplication
import LatestPlatform

struct LatestSettings: View {
    @Bindable var model: AppModel
    @State private var section = 0
    var body: some View {
        VStack(spacing: 14) {
            NativeSegmentedChoice(selection: $section, options: [(0, LocalizedStringResource("General")), (1, LocalizedStringResource("Locations"))],
                                  label: "Settings…", identifier: "settings-section", scale: model.preferences.fontScale)
                .fixedSize()
            if section == 0 { GeneralSettings(model: model) }
            else { DirectorySettings(model: model) }
        }.font(.system(size: 14 * model.preferences.fontScale))
            .controlSize(model.preferences.fontScale >= 1.3 ? .large : .regular)
            .padding().frame(minWidth: 560, minHeight: 440)
    }
}
private struct GeneralSettings: View {
    @Bindable var model: AppModel
    var body: some View {
        Form {
            Toggle("Show Up-to-date Apps", isOn: $model.preferences.showCurrent).accessibilityIdentifier("show-current")
            Toggle("Show Ignored and Skipped Apps", isOn: $model.preferences.showIgnored).accessibilityIdentifier("show-ignored")
            Toggle("Show Unknown and Incompatible Apps", isOn: $model.preferences.showUnknown).accessibilityIdentifier("show-unknown")
            Toggle("Sort by Source", isOn: $model.preferences.sortBySource).accessibilityIdentifier("sort-by-source")
            Toggle("Show Informational Catalogue Hints", isOn: $model.preferences.showCatalogueHints)
            LabeledContent("Text Size") {
                Slider(value: $model.preferences.fontScale, in: 1...1.6).frame(width: 160)
                    .accessibilityLabel(Text("Text Size")).accessibilityIdentifier("text-size")
                    .accessibilityValue(model.preferences.fontScale.formatted(.percent.precision(.fractionLength(0))))
            }
            Section("App Store Updates") {
                Text("Direct updates require the signed installation helper. iOS apps, duplicate installations and nonstandard locations open the App Store instead.")
                Button { model.enableBroker() } label: {
                    Text("Enable Installation Helper").font(.system(size: 14 * model.preferences.fontScale))
                }
                if model.needsBrokerApproval { Text("Approve Latest in System Settings → General → Login Items & Extensions.").foregroundStyle(.orange) }
            }
        }.formStyle(.grouped)
    }
}
private struct DirectorySettings: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Choose which folders Latest scans. Disabling a folder excludes its apps.").foregroundStyle(.secondary)
            List {
                ForEach($model.preferences.directories) { $directory in
                    HStack {
                        Toggle(directory.path, isOn: $directory.enabled).lineLimit(2)
                            .accessibilityIdentifier("directory-enabled-" + directory.path)
                        Button("Remove", systemImage: "minus.circle") {
                            // Read the binding before mutating its containing preferences.
                            let path = directory.path
                            model.preferences.directories.removeAll { $0.path == path }
                        }.labelStyle(.iconOnly).accessibilityIdentifier("directory-remove-" + directory.path)
                    }
                }
            }
            Button("Add Folder…", systemImage: "plus") { chooseDirectory() }.accessibilityIdentifier("add-directory")
        }
    }
    private func chooseDirectory() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url { model.addDirectory(url) }
    }

}
