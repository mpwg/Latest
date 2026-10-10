import Foundation

/// Reply, cancellation, interruption and timeout race to one terminal result.
public actor CompletionGate<Value: Sendable> {
    private var result: Result<Value, LatestFailure>?
    private var waiters: [CheckedContinuation<Value, Error>] = []
    public init() {}
    public func wait() async throws -> Value {
        if let result { return try result.get() }
        return try await withCheckedThrowingContinuation { waiters.append($0) }
    }
    @discardableResult public func finish(_ result: Result<Value, LatestFailure>) -> Bool {
        guard self.result == nil else { return false }
        self.result = result
        for waiter in waiters { waiter.resume(with: result.mapError { $0 as any Error }) }
        waiters.removeAll()
        return true
    }
}
