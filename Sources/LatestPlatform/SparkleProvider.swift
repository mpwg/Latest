import AppKit
import Foundation
import Sparkle
import LatestCore

public struct SparkleProvider: UpdateProvider {
    public init() {}
    public func check(_ app: AppSnapshot, context: CheckContext) async throws -> UpdateCandidate? {
        guard !app.hasReceipt, app.feedURL != nil else { return nil }
        let channel = context.preferences.channels[app.id.path, default: .stable]
        if let url = app.feedURL, !FeedPolicy.compatible(url, with: app.architectures) {
            return .init(app: app, source: .sparkle, version: app.version, action: .external(app.id.url),
                         authoritative: false, comparison: .unknown)
        }
        return try await SparkleSession.check(app, channel: channel)
    }
    @MainActor public func install(_ candidate: UpdateCandidate, channel: ReleaseChannel,
                                   event: @escaping @MainActor @Sendable (UpdateEvent) -> Void) async throws {
        try await SparkleSession.install(candidate, channel: channel, event: event)
    }
}

@MainActor final class SparkleSession: NSObject, SPUUserDriver, SPUUpdaterDelegate {
    private let app: AppSnapshot
    private let channel: ReleaseChannel
    private let installing: Bool
    private let expectedVersion: AppVersion?
    private var updater: SPUUpdater?
    private var completion: CheckedContinuation<UpdateCandidate?, Error>?
    private var cancellation: (() -> Void)?
    private var event: (@MainActor @Sendable (UpdateEvent) -> Void)?
    private var completed = false
    private var expectedBytes: UInt64 = 0
    private var receivedBytes: UInt64 = 0
    private var downloadPhase = false
    private var handedOff = false

    init(app: AppSnapshot, channel: ReleaseChannel, installing: Bool, expectedVersion: AppVersion? = nil,
         event: (@MainActor @Sendable (UpdateEvent) -> Void)? = nil) {
        self.app = app; self.channel = channel; self.installing = installing
        self.expectedVersion = expectedVersion; self.event = event
    }

    static func check(_ app: AppSnapshot, channel: ReleaseChannel) async throws -> UpdateCandidate? {
        let session = SparkleSession(app: app, channel: channel, installing: false)
        return try await session.run()
    }
    static func install(_ candidate: UpdateCandidate, channel: ReleaseChannel,
                        event: @escaping @MainActor @Sendable (UpdateEvent) -> Void) async throws {
        let session = SparkleSession(app: candidate.app, channel: channel, installing: true,
                                    expectedVersion: candidate.version, event: event)
        _ = try await session.run()
    }
    private func run() async throws -> UpdateCandidate? {
        let limit = Duration.seconds(installing ? 1200 : 45)
        let timeout = Task { @MainActor [weak self] in
            try await Task.sleep(for: limit)
            self?.expire()
        }
        defer { timeout.cancel() }
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                completion = continuation
                guard let bundle = Bundle(url: app.id.url), app.feedURL?.scheme == "https" else {
                    finish(.failure(LatestFailure.rejected("The Sparkle host is unavailable or its feed is insecure."))); return
                }
                let instance = SPUUpdater(hostBundle: bundle, applicationBundle: bundle, userDriver: self, delegate: self)
                updater = instance
                do { try instance.start() }
                catch { finish(.failure(error)); return }
                instance.checkForUpdates()
            }
        } onCancel: { Task { @MainActor in self.cancel() } }
    }
    private func finish(_ result: Result<UpdateCandidate?, Error>) {
        guard !completed else { return }
        completed = true; downloadPhase = false
        let callback = completion; completion = nil
        cancellation = nil; updater = nil; event = nil
        callback?.resume(with: result)
    }
    func cancel() {
        guard !completed, !handedOff else { return }
        let callback = cancellation; cancellation = nil
        finish(.failure(CancellationError()))
        callback?()
    }
    private func expire() {
        guard !completed else { return }
        let callback = handedOff ? nil : cancellation
        finish(.failure(LatestFailure.timeout))
        callback?()
    }
    private func candidate(_ item: SUAppcastItem) -> UpdateCandidate {
        .init(app: app, source: .sparkle, version: .init(display: item.displayVersionString, build: item.versionString),
              action: .sparkle(app.feedURL!), authoritative: true,
              channel: channel, minimumOS: item.minimumSystemVersion,
              releaseNotes: item.itemDescription, releaseNotesURL: item.releaseNotesURL ?? item.fullReleaseNotesURL, releaseDate: item.date)
    }
    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        reply(.init(automaticUpdateChecks: false, sendSystemProfile: false))
    }
    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        guard !completed else { cancellation(); return }
        self.cancellation = cancellation
    }
    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        guard !completed else { reply(.dismiss); return }
        let result = candidate(appcastItem)
        if let fileURL = appcastItem.fileURL, !FeedPolicy.compatible(fileURL, with: app.architectures) {
            reply(.dismiss); finish(.failure(LatestFailure.rejected("This Sparkle update targets a different architecture or insecure URL. Use the app's own updater."))); return
        }
        if installing {
            guard result.version == expectedVersion else {
                reply(.dismiss); finish(.failure(LatestFailure.rejected("The Sparkle update changed; check for updates again."))); return
            }
            reply(.install)
        } else { reply(.dismiss); finish(.success(result)) }
    }
    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        acknowledgement()
        let value = error as NSError
        if !installing, value.domain == SUSparkleErrorDomain, value.code == SUError.noUpdateError.rawValue {
            if let item = value.userInfo[SPULatestAppcastItemFoundKey] as? SUAppcastItem { finish(.success(candidate(item))) }
            else { finish(.success(nil)) }
        } else { finish(.failure(error)) }
    }
    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) { acknowledgement(); finish(.failure(error)) }
    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) { acknowledgement(); finish(.success(nil)) }
    func showUpdateInFocus() {}
    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        guard !completed else { cancellation(); return }
        guard !handedOff else { return }
        self.cancellation = cancellation; downloadPhase = true; receivedBytes = 0; expectedBytes = 0
        event?(.init(.downloading))
    }
    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        guard !completed, downloadPhase else { return }
        expectedBytes = expectedContentLength
    }
    func showDownloadDidReceiveData(ofLength length: UInt64) {
        guard !completed, downloadPhase else { return }
        receivedBytes &+= length
        event?(.init(.downloading, progress: expectedBytes > 0 ? Double(receivedBytes) / Double(expectedBytes) : nil))
    }
    func showDownloadDidStartExtractingUpdate() {
        guard !completed else { return }
        // Sparkle's download cancellation block is invalid from extraction onward.
        handedOff = true; cancellation = nil; downloadPhase = false
        event?(.init(.installing))
    }
    func showExtractionReceivedProgress(_ progress: Double) {}
    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) { reply(completed ? .dismiss : .install) }
    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        guard !completed else { return }
        handedOff = true; downloadPhase = false; cancellation = nil; event?(.init(.installing))
    }
    func showCanCheck(forUpdates canCheckForUpdates: Bool) {}
    func dismissUserInitiatedUpdateCheck() {}
    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}
    func showSendingTerminationSignal() {}
    func dismissUpdateInstallation() {}
    func feedURLString(for updater: SPUUpdater) -> String? { app.feedURL?.absoluteString }
    func allowedChannels(for updater: SPUUpdater) -> Set<String> { channel == .beta ? ["beta", "stable"] : ["stable"] }
}
