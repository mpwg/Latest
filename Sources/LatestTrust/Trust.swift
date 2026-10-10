import Foundation
import Security
import CryptoKit
import LatestCore
import LatestContracts

public enum CodeTrust {
    public struct SigningIdentity: Sendable {
        public let digest: String
        public let team: String?
    }
    /// Fast signature metadata is identity evidence; integrity is checked separately before installation.
    public static func signingIdentity(_ url: URL) -> SigningIdentity? {
        var code: SecStaticCode?
        var information: CFDictionary?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,
              SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let values = information as? [String: Any], let hash = values[kSecCodeInfoUnique as String] as? Data else { return nil }
        return .init(digest: hash.map { String(format: "%02x", $0) }.joined(), team: values[kSecCodeInfoTeamIdentifier as String] as? String)
    }
    public static func verifyPresentSignature(_ url: URL) throws {
        guard signingIdentity(url) != nil else { return }
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures), nil) == errSecSuccess else {
            throw LatestFailure.rejected("Code signature verification failed.")
        }
    }
    public static func verify(_ url: URL, requirement text: String) throws {
        var code: SecStaticCode?
        var requirement: SecRequirement?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,
              SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess, let requirement,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures), requirement) == errSecSuccess else {
            throw LatestFailure.rejected("Code signature verification failed.")
        }
    }
    public static func sha256(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while let data = try handle.read(upToCount: 65536), !data.isEmpty { hash.update(data: data) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

public struct BrokerConfiguration: Sendable {
    public let team: String
    public let masHash: String
    public let verifierHash: String
    public init(team: String, masHash: String, verifierHash: String) throws {
        _ = try ForkIdentity.requirement(identifier: ForkIdentity.application, team: team)
        guard [masHash, verifierHash].allSatisfy({ $0.count == 64 && $0.allSatisfy { $0.isHexDigit && $0.isASCII } }) else {
            throw LatestFailure.rejected("The bundled App Store tool has no valid build pin.")
        }
        self.team = team; self.masHash = masHash.lowercased(); self.verifierHash = verifierHash.lowercased()
    }
    public static func load(appURL: URL) throws -> Self {
        guard let bundle = Bundle(url: appURL), let info = bundle.infoDictionary,
              let team = info["LatestSigningTeam"] as? String, let hash = info["LatestMasSHA256"] as? String,
              let verifierHash = info["LatestVerifierSHA256"] as? String else {
            throw LatestFailure.rejected("Signed App Store update configuration is unavailable.")
        }
        let result = try Self(team: team, masHash: hash, verifierHash: verifierHash)
        try CodeTrust.verify(appURL, requirement: ForkIdentity.requirement(identifier: ForkIdentity.application, team: team))
        return result
    }
}
