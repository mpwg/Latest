import Foundation

public struct CaskMetadata: Sendable, Equatable {
    public let token: String
    public let version: String
    public let installed: String?
    public let names: Set<String>
    public let autoUpdates: Bool
    public let minimumOS: String?
    public let outdated: Bool
}

public enum Metadata {
    public static func outdatedCaskTokens(_ data: Data) throws -> Set<String> {
        guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = dictionary["casks"] as? [[String: Any]] else { throw LatestFailure.network("Invalid outdated cask metadata.") }
        return Set(try list.map { item in
            guard let token = item["name"] as? String, validToken(token), item["current_version"] is String else {
                throw LatestFailure.network("Invalid outdated cask entry.")
            }
            return token
        })
    }
    /// Invalid entries are isolated. No individual remote item may discard its neighbours.
    public static func casks(_ data: Data) throws -> [CaskMetadata] {
        let object = try JSONSerialization.jsonObject(with: data)
        let list: [[String: Any]]
        if let values = object as? [[String: Any]] { list = values }
        else if let dictionary = object as? [String: Any], let values = dictionary["casks"] as? [[String: Any]] { list = values }
        else { throw LatestFailure.network("Invalid Homebrew metadata.") }
        return list.compactMap { entry in
            guard let token = entry["token"] as? String, validToken(token), let version = entry["version"] as? String else { return nil }
            var names = Set<String>()
            for artifact in entry["artifacts"] as? [[String: Any]] ?? [] {
                for item in artifact["app"] as? [Any] ?? [] {
                    if let path = item as? String { names.insert(URL(fileURLWithPath: path).lastPathComponent) }
                    if let dictionary = item as? [String: String], let path = dictionary["target"] { names.insert(URL(fileURLWithPath: path).lastPathComponent) }
                }
            }
            var minimum: String?
            if let dependencies = entry["depends_on"] as? [String: Any], let os = dependencies["macos"] as? [String: Any],
               let values = os[">="] as? [String], let first = values.first, !first.isEmpty { minimum = first }
            return CaskMetadata(token: token, version: version, installed: entry["installed"] as? String,
                                names: names, autoUpdates: entry["auto_updates"] as? Bool ?? false,
                                minimumOS: minimum, outdated: entry["outdated"] as? Bool ?? false)
        }
    }
    public static func validToken(_ token: String) -> Bool {
        !token.isEmpty && token.utf8.count <= 128 && token.first != "-"
        && token.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "-._@".contains($0)) }
    }

    public static func exclusions(_ data: Data) throws -> Set<String> {
        guard data.count <= 500_000,
              let values = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String],
              values.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 255 }) else {
            throw LatestFailure.network("Invalid exclusion metadata.")
        }
        return Set(values)
    }
}
