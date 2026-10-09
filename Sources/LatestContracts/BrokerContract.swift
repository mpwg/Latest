import Foundation

@objc public protocol LatestBrokerProtocol {
    func update(_ request: Data, reply: @escaping @Sendable (Data?, NSError?) -> Void)
}

public enum ForkIdentity {
    public static let application = "io.github.mpwg.Latest"
    public static let broker = "io.github.mpwg.Latest.Broker"
    public static let tool = "io.github.mpwg.Latest.mas"
    public static func requirement(identifier: String, team: String) throws -> String {
        guard team.count == 10, team.allSatisfy({ $0.isASCII && ($0.isUppercase || $0.isNumber) }),
              [application, broker, tool].contains(identifier) else {
            throw IdentityError.unconfigured
        }
        return "anchor apple generic and identifier \"\(identifier)\" and certificate leaf[subject.OU] = \"\(team)\""
    }
    public enum IdentityError: Error { case unconfigured }
}
