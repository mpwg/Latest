import Foundation

public struct AppStoreClaim: Codable, Equatable, Sendable {
    public let storeID: UInt64
    public let bundleID: String
    public let path: String
    public init(storeID: UInt64, bundleID: String, path: String) {
        self.storeID = storeID; self.bundleID = bundleID; self.path = path
    }
}

public enum BrokerPolicy {
    public static func validate(_ claim: AppStoreClaim, installed: [AppStoreClaim], outdatedIDs: Set<UInt64>) throws {
        guard claim.storeID > 0, claim.storeID <= UInt64(Int64.max), !claim.bundleID.isEmpty,
              claim.bundleID.utf8.count <= 255, claim.bundleID.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || ".-_".contains($0)) }),
              claim.path.hasPrefix("/Applications/"), claim.path.hasSuffix(".app"),
              URL(fileURLWithPath: claim.path).standardizedFileURL.path == claim.path,
              URL(fileURLWithPath: claim.path).deletingLastPathComponent().path == "/Applications" else {
            throw LatestFailure.rejected("The App Store update request is invalid or targets a nonstandard location.")
        }
        let instances = installed.filter { $0.storeID == claim.storeID || $0.bundleID == claim.bundleID }
        guard instances.count == 1, instances.first == claim, outdatedIDs.contains(claim.storeID) else {
            throw LatestFailure.rejected("The App Store installation is ambiguous, changed, or no longer outdated.")
        }
    }
    public static func arguments(for claim: AppStoreClaim) throws -> [String] {
        guard claim.storeID > 0, claim.storeID <= UInt64(Int64.max) else { throw LatestFailure.rejected("Invalid App Store ID.") }
        return ["update", String(claim.storeID)]
    }
}
