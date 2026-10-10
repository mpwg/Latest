import Foundation
import LatestCore

public enum MasMetadata {
    /// mas v7 writes one JSON object per line with normalized Spotlight keys.
    public static func installed(_ data: Data) throws -> [AppStoreClaim] {
        try objects(data).map { object in
            guard let id = (object["adamID"] as? NSNumber)?.uint64Value, id > 0,
                  let bundle = object["bundleID"] as? String, let path = object["path"] as? String else {
                throw LatestFailure.process("Invalid mas installation metadata.")
            }
            return .init(storeID: id, bundleID: bundle, path: path)
        }
    }
    public static func outdated(_ data: Data) throws -> Set<UInt64> {
        Set(try objects(data).map { object in
            // v7 adds newVersion to the same flat normalized installation object.
            guard let id = (object["adamID"] as? NSNumber)?.uint64Value, id > 0, object["newVersion"] is String else {
                throw LatestFailure.process("Invalid mas outdated metadata.")
            }
            return id
        })
    }
    private static func objects(_ data: Data) throws -> [[String: Any]] {
        guard let string = String(data: data, encoding: .utf8) else { throw LatestFailure.process("Invalid tool encoding.") }
        return try string.split(whereSeparator: \.isNewline).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.map { line in
            guard let object = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else {
                throw LatestFailure.process("Unexpected mas output.")
            }
            return object
        }
    }
}
