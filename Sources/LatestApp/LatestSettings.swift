import SwiftUI
import LatestPlatform

struct LatestSettings: View {
    @Bindable var model: AppModel
    var body: some View {
        TabView {
            GeneralSettings(model: model).tabItem { Label("General", systemImage: "gear") }
            DirectorySettings(model: model).tabItem { Label("Locations", systemImage: "folder") }
        }.frame(width: 560, height: 440).padding()
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
            LabeledContent("Text Size") { Slider(value: $model.preferences.fontScale, in: 1...1.6).frame(width: 160) }
            Section("App Store Updates") {
                Text("Direct updates require the signed installation helper. iOS apps, duplicate installations and nonstandard locations open the App Store instead.")
                Button("Enable Installation Helper") { model.enableBroker() }
                if model.needsBrokerApproval { Text("Approve Latest in System Settings → General → Login Items & Extensions.").foregroundStyle(.orange) }
            }
        }.formStyle(.grouped).onChange(of: model.preferences) { _, _ in model.save() }
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
            Button("Add Folder…", systemImage: "plus") { model.addDirectory() }.accessibilityIdentifier("add-directory")
        }.onChange(of: model.preferences.directories) { _, _ in model.save(); model.refresh() }
    }
}
