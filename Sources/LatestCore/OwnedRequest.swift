import Foundation

/// Disconnect cancels preflight; an installer handoff completes under its own bounded deadline.
public actor OwnedRequest {
    private var task: Task<Void, Never>?
    private var disconnected = false
    private var handedOff = false
    public init() {}
    public func start(_ operation: @escaping @Sendable (OwnedRequest) async -> Void) -> Bool {
        guard task == nil, !disconnected else { return false }
        task = Task { await operation(self) }
        return true
    }
    public func handOffToInstaller() throws {
        guard !disconnected, !Task.isCancelled else { throw LatestFailure.cancelled }
        handedOff = true
    }
    public func disconnect() {
        disconnected = true
        if !handedOff { task?.cancel() }
    }
    public func finish() { task = nil }
}
