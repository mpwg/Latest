import Foundation

/// An authenticated Apple package may only replace the selected application subtree.
public enum PackagePolicy {
    public static func validate(bundleIDs: Set<String>, installLocations: Set<String>, payloadPaths: [String],
                                containsScripts: Bool, claim: AppStoreClaim) throws {
        guard !containsScripts, bundleIDs == [claim.bundleID], !payloadPaths.isEmpty,
              installLocations.count == 1, let location = installLocations.first,
              location == "/Applications" || location == claim.path else {
            throw LatestFailure.rejected("The App Store package targets unrelated content or includes install scripts.")
        }
        let target = URL(fileURLWithPath: claim.path).lastPathComponent
        for path in payloadPaths {
            var value = path
            if value.hasPrefix("./") { value.removeFirst(2) }
            if value == "." || value.isEmpty { continue }
            let parts = value.split(separator: "/", omittingEmptySubsequences: false)
            guard !value.hasPrefix("/"), !parts.contains(".."), !parts.contains(""),
                  location == claim.path || parts.first == Substring(target) else {
                throw LatestFailure.rejected("The App Store package writes outside the selected application.")
            }
        }
    }
}
