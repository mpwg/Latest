import Foundation

public enum Presentation {
    public static func visible(_ records: [AppRecord], query: String, source: UpdateSource?, preferences: Preferences) -> [AppRecord] {
        records.filter { record in
            if !query.isEmpty && !record.app.name.localizedCaseInsensitiveContains(query) && !record.app.bundleID.localizedCaseInsensitiveContains(query) { return false }
            if let source, record.candidate?.source != source { return false }
            if !preferences.showCurrent && record.status == .current { return false }
            if !preferences.showIgnored && [.ignored, .skipped].contains(record.status) { return false }
            if !preferences.showUnknown && [.unknown, .incompatible].contains(record.status) { return false }
            return true
        }.sorted {
            if preferences.sortBySource, $0.candidate?.source != $1.candidate?.source {
                return ($0.candidate?.source.rawValue ?? "unknown") < ($1.candidate?.source.rawValue ?? "unknown")
            }
            let comparison = $0.app.name.localizedStandardCompare($1.app.name)
            return comparison == .orderedSame ? $0.id.path < $1.id.path : comparison == .orderedAscending
        }
    }
    public static func bulkEligible(_ candidate: UpdateCandidate, status: AppStatus) -> Bool {
        guard status == .available, !candidate.isMajorUpgrade, candidate.authoritative else { return false }
        return switch candidate.action { case .appStore, .homebrew, .sparkle: true; default: false }
    }
}
