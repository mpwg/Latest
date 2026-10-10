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
}
