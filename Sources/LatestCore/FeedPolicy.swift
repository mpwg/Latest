import Foundation

public enum FeedPolicy {
    /// Explicit architecture-specific URLs may never switch an installed native build.
    public static func compatible(_ url: URL, with architectures: Set<Architecture>) -> Bool {
        guard url.scheme == "https", url.user == nil, url.password == nil else { return false }
        let path = url.path.lowercased()
        let arm = path.contains("arm64") || path.contains("aarch64")
        let intel = path.contains("x86_64") || path.contains("x86-64") || path.contains("amd64")
        if arm && !intel && !architectures.isEmpty { return architectures.contains(.arm64) }
        if intel && !arm && architectures == [.arm64] { return false }
        return true
    }
}
