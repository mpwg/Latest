import Foundation
import CryptoKit

public struct HTTPResponse: Sendable { public let data: Data; public let stale: Bool }

private final class HTTPSRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        let url = request.url
        completionHandler(url?.scheme == "https" && url?.user == nil && url?.password == nil ? request : nil)
    }
}

/// The ephemeral session follows redirects; validate both the requested and final URL.
public actor BoundedHTTPClient {
    private let session: URLSession
    private let cacheDirectory: URL
    public init(cacheDirectory: URL, testSession: URLSession? = nil) {
        self.cacheDirectory = cacheDirectory
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 45
        configuration.httpMaximumConnectionsPerHost = 4
        session = testSession ?? URLSession(configuration: configuration, delegate: HTTPSRedirectPolicy(), delegateQueue: nil)
    }
    public func fetch(_ url: URL, maximumBytes: Int = 4_000_000,
                      validate: @Sendable (Data) throws -> Void = { _ in }) async throws -> HTTPResponse {
        guard url.scheme?.lowercased() == "https", url.host != nil, url.user == nil, url.password == nil,
              maximumBytes > 0, maximumBytes <= 32_000_000 else { throw LatestFailure.rejected("Only HTTPS resources are permitted.") }
        let key = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        let cache = cacheDirectory.appendingPathComponent(key + ".json")
        do {
            var request = URLRequest(url: url)
            request.setValue("Latest/1 (mpwg/Latest)", forHTTPHeaderField: "User-Agent")
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  response.url?.scheme == "https" else { throw LatestFailure.network("The server returned an invalid response.") }
            if response.expectedContentLength > maximumBytes { throw LatestFailure.network("The response exceeds the size limit.") }
            var data = Data()
            for try await byte in bytes {
                try Task.checkCancellation()
                guard data.count < maximumBytes else { throw LatestFailure.network("The response exceeds the size limit.") }
                data.append(byte)
            }
            try validate(data)
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            try data.write(to: cache, options: .atomic)
            return HTTPResponse(data: data, stale: false)
        } catch {
            if Task.isCancelled { throw CancellationError() }
            if let attributes = try? FileManager.default.attributesOfItem(atPath: cache.path),
               let size = attributes[.size] as? Int, size <= maximumBytes,
               let date = attributes[.modificationDate] as? Date, Date().timeIntervalSince(date) <= 7 * 86400,
               let data = try? Data(contentsOf: cache), (try? validate(data)) != nil {
                return HTTPResponse(data: data, stale: true)
            }
            throw error
        }
    }
}

public enum SafeText {
    /// Remove active markup before rendering as plain text. No HTML renderer or web view is used.
    public static func releaseNotes(_ input: String, maximumCharacters: Int = 100_000) -> String {
        var text = String(input.prefix(maximumCharacters))
        for pattern in [#"(?is)<(script|style|iframe|object)\b[^>]*>.*?</\1\s*>"#,
                        #"(?is)<[^>]+>"#] {
            text = text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        return text.replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
