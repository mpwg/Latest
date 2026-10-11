import Foundation

/// Compiled with the actual LatestCore sources; uses the production TLS session.
@main struct NetworkAcceptance {
    static func main() async throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 4, let port = Int(arguments[3]), (1024...65535).contains(port) else {
            throw LatestFailure.rejected("Expected mode, private evidence directory and unprivileged port.")
        }
        let mode = arguments[1]
        let root = URL(fileURLWithPath: arguments[2])
        let cache = root.appendingPathComponent("cache")
        let http = BoundedHTTPClient(cacheDirectory: cache)
        let endpoint = URL(string: "https://localhost:\(port)/resource")!
        var result: [String: Any] = ["mode": mode, "transport": "production URLSession, no URLProtocol override"]
        if mode == "sample" {
            let response = try await http.fetch(URL(string: "https://formulae.brew.sh/api/cask.json")!, maximumBytes: 32_000_000) {
                _ = try Metadata.casks($0)
            }
            guard !response.stale else { throw LatestFailure.network("A current provider sample must come from the network.") }
            let entries = try Metadata.casks(response.data)
            guard !entries.isEmpty else { throw LatestFailure.network("Current cask catalogue is empty.") }
            try response.data.write(to: root.appendingPathComponent("provider-sample.json"), options: .atomic)
            result["bytes"] = response.data.count; result["decodedEntries"] = entries.count
        } else if mode == "certificate" || mode == "redirect" {
            let url = mode == "certificate" ? URL(string: "https://[::1]:\(port)/resource")! : URL(string: "https://localhost:\(port)/redirect")!
            do {
                _ = try await http.fetch(url)
                throw LatestFailure.process("An unsafe native transport was accepted.")
            } catch let error as URLError where mode == "certificate" {
                guard [.serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot,
                       .serverCertificateNotYetValid, .secureConnectionFailed].contains(error.code) else { throw error }
                result["rejected"] = "TLS hostname/certificate validation"
                result["nativeErrorCode"] = error.errorCode
            } catch LatestFailure.network(let reason) where mode == "redirect" {
                result["rejected"] = reason
            }
        } else if mode == "stream-limit" {
            let uncached = BoundedHTTPClient(cacheDirectory: root.appendingPathComponent("no-good-cache"))
            do {
                _ = try await uncached.fetch(endpoint, maximumBytes: 65_536) { _ = try Metadata.casks($0) }
                throw LatestFailure.process("An unknown-length oversized native stream was accepted.")
            } catch LatestFailure.network(let reason) {
                guard reason == "The response exceeds the size limit." else { throw LatestFailure.network(reason) }
                result["rejected"] = reason
            }
        } else if mode == "cancelled" {
            let request = Task { try await http.fetch(endpoint, maximumBytes: 65_536) { _ = try Metadata.casks($0) } }
            let marker = root.appendingPathComponent("stream-started")
            let deadline = ContinuousClock.now.advanced(by: .seconds(10))
            while !FileManager.default.fileExists(atPath: marker.path) {
                guard ContinuousClock.now < deadline else { request.cancel(); throw LatestFailure.timeout }
                try await Task.sleep(for: .milliseconds(20))
            }
            request.cancel()
            do { _ = try await request.value; throw LatestFailure.process("Cancelled native transport returned data or stale cache.") }
            catch is CancellationError { result["cancelled"] = true }
        } else if mode == "expired" || mode == "corrupt" || mode == "oversized-cache" {
            do {
                _ = try await http.fetch(endpoint, maximumBytes: 65_536) { _ = try Metadata.casks($0) }
                throw LatestFailure.process("An invalid offline cache was accepted.")
            } catch let error as URLError {
                result["rejectedCache"] = mode; result["nativeErrorCode"] = error.errorCode
            }
        } else {
            let response = try await http.fetch(endpoint, maximumBytes: 65_536) { _ = try Metadata.casks($0) }
            let expected = try Data(contentsOf: root.appendingPathComponent("valid-resource.json"))
            guard response.data == expected, response.stale == (mode != "valid") else {
                throw LatestFailure.network("Unexpected native data or stale flag.")
            }
            let entries = try Metadata.casks(response.data)
            guard entries.count == 2 else { throw LatestFailure.network("Malformed neighbours discarded a valid provider entry.") }
            result["stale"] = response.stale; result["decodedEntries"] = entries.count
            result["bytes"] = response.data.count
        }
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    }
}
