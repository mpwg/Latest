import Foundation

/// Deterministic transport responses; production still uses its own HTTPS-only session.
final class HTTPFixture: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "fixture.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url, let client else { return }
        if url.path == "/offline" { client.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)); return }
        let status = url.path == "/error" ? 503 : 200
        let final = url.path == "/downgrade" ? URL(string: "http://fixture.invalid/unsafe")! : url
        guard let response = HTTPURLResponse(url: final, statusCode: status, httpVersion: "HTTP/1.1", headerFields: [:]) else { return }
        client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        let content = url.path == "/large" ? Data(repeating: 65, count: 4096) : url.path == "/invalid" ? Data("invalid json".utf8) : Data("{\"valid\":true}".utf8)
        client.urlProtocol(self, didLoad: content)
        client.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class OfflineFixture: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}
