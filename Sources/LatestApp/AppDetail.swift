import SwiftUI
import LatestApplication
import AppKit
import LatestCore

struct AppDetail: View {
    let row: AppRow
    @Bindable var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AppDetailHeader(row: row)
                AppDetailActions(row: row, model: model)
                AppDetailMetadata(row: row, model: model)
                ReleaseNotesSection(text: model.notes, loading: model.loadingNotes, url: row.record.candidate?.releaseNotesURL, scale: model.preferences.fontScale)
            }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
        }.textSelection(.enabled)
    }
}
private struct AppDetailHeader: View {
    let row: AppRow
    var body: some View {
        HStack(spacing: 18) {
            Image(nsImage: row.icon).resizable().frame(width: 72, height: 72).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(row.record.app.name).font(.title)
                    .accessibilityLabel(Text(verbatim: row.record.app.name)).accessibilityIdentifier("selected-app-name")
                Text(row.record.app.version.description).foregroundStyle(.secondary)
                    .accessibilityValue(row.record.app.version.description).accessibilityIdentifier("installed-version")
                if let candidate = row.record.candidate { Text("New version: \(candidate.version.description)") }
                StatusTitle(status: row.record.status).accessibilityIdentifier("selected-status")
            }
        }
    }
}
private struct AppDetailActions: View {
    let row: AppRow
    let model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let event = row.event, !event.isTerminal {
                    ProgressView(value: event.progress).frame(width: 160)
                    Text(event.phase.rawValue.capitalized)
                    Button("Cancel") { model.cancel(row.id) }.disabled(!model.canCancel(row.id))
                        .accessibilityIdentifier("cancel-update")
                } else {
                    Button { model.requestUpdate(row.id) } label: {
                        if row.record.status == .external { Text("Open Updater") }
                        else { Text("Update") }
                    }
                        .buttonStyle(.borderedProminent)
                        .disabled(!model.canUpdate(row.id))
                        .accessibilityIdentifier("update-selected")
                }
                Button("Open App") { NSWorkspace.shared.open(row.id.url) }
                Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([row.id.url]) }
            }
            if row.record.candidate?.isMajorUpgrade == true { Label("Major Upgrade", systemImage: "exclamationmark.circle").foregroundStyle(.orange) }
            if let message = row.event?.message { Text(message).foregroundStyle(.red) }
            if let reason = row.record.reason { Text(reason).foregroundStyle(.secondary) }
        }
    }
}
private struct AppDetailMetadata: View {
    let row: AppRow
    @Bindable var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent("Source") { SourceTitle(source: row.record.candidate?.source ?? .unknown) }
            LabeledContent("Location") {
                Text(row.id.path).font(.caption).lineLimit(3)
                    .accessibilityValue(row.id.path).accessibilityIdentifier("selected-app-location")
            }
            LabeledContent("Bundle Identifier") {
                Text(row.record.app.bundleID).font(.caption)
                    .accessibilityValue(row.record.app.bundleID).accessibilityIdentifier("selected-app-bundle-id")
            }
            Picker("Release Channel", selection: Binding(get: { model.preferences.channels[row.id.path, default: .stable] }, set: { model.preferences.channels[row.id.path] = $0 })) {
                Text("Stable").tag(ReleaseChannel.stable)
                Text("Beta").tag(ReleaseChannel.beta)
            }.pickerStyle(.segmented).frame(maxWidth: 260).accessibilityIdentifier("release-channel")
            HStack {
                Button { model.ignore(row.id) } label: {
                    if model.preferences.ignoredBundleIDs.contains(row.record.app.bundleID) { Text("Stop Ignoring") }
                    else { Text("Ignore App") }
                }.accessibilityIdentifier("ignore-selected")
                Button("Skip This Version") { model.skip(row.id) }.disabled(row.record.candidate == nil)
                    .accessibilityIdentifier("skip-selected")
                if row.record.status == .skipped {
                    Button("Clear Skipped Version") { model.clearSkip(row.id) }.accessibilityIdentifier("clear-skip-selected")
                }
            }
        }
    }
}
private struct ReleaseNotesSection: View {
    let text: String
    let loading: Bool
    let url: URL?
    let scale: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Release Notes").font(.headline)
            if loading { ProgressView() }
            else if text.isEmpty { Text("No release notes are available.").foregroundStyle(.secondary) }
            else { Text(text).font(.system(size: 14 * scale)).accessibilityIdentifier("release-notes") }
            if let url, url.scheme == "https" { Link("Open Original Release Notes", destination: url) }
        }
    }
}
