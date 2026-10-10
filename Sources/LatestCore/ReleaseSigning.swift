import Foundation
import CryptoKit

public enum ReleaseSigning {
    public static func publicKey(seed: Data) throws -> String {
        try Curve25519.Signing.PrivateKey(rawRepresentation: seed).publicKey.rawRepresentation.base64EncodedString()
    }
    public static func signature(data: Data, seed: Data) throws -> String {
        try Curve25519.Signing.PrivateKey(rawRepresentation: seed).signature(for: data).base64EncodedString()
    }
    public static func signedFeed(_ data: Data, seed: Data) throws -> Data {
        let signature = try signature(data: data, seed: seed)
        return data + Data("<!-- sparkle-signatures:\nedSignature: \(signature)\nlength: \(data.count)\n-->\n".utf8)
    }
    public static func verify(data: Data, signature: String, publicKey: String) throws -> Bool {
        guard let bytes = Data(base64Encoded: signature), let key = Data(base64Encoded: publicKey) else { return false }
        return try Curve25519.Signing.PublicKey(rawRepresentation: key).isValidSignature(bytes, for: data)
    }
    public static func verifyFeed(_ data: Data, publicKey: String) throws -> Bool {
        let marker = Data("<!-- sparkle-signatures:\n".utf8)
        guard let range = data.range(of: marker),
              data.range(of: marker, in: range.upperBound..<data.endIndex) == nil,
              let envelope = String(data: data[range.upperBound...], encoding: .utf8) else { return false }
        let lines = envelope.components(separatedBy: "\n")
        guard lines.count == 4, lines[0].hasPrefix("edSignature: "),
              lines[1] == "length: \(range.lowerBound)", lines[2] == "-->", lines[3].isEmpty else { return false }
        return try verify(data: Data(data[..<range.lowerBound]),
                          signature: String(lines[0].dropFirst("edSignature: ".count)), publicKey: publicKey)
    }
}
