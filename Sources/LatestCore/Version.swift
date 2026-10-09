import Foundation

/// Value equality is structural. Source-specific update ordering is explicit.
public struct AppVersion: Codable, Hashable, Sendable {
    public let display: String?
    public let build: String?

    public init(display: String?, build: String? = nil) {
        self.display = Self.clean(display)
        self.build = Self.clean(build)
    }

    public var description: String {
        if let display, let build, display != build { return "\(display) (\(build))" }
        return display ?? build ?? "—"
    }

    public var major: Int? {
        guard let display, let first = Self.tokens(display)?.first,
              case .number(let value) = first, let number = Int(value), number < 2000 else { return nil }
        return number
    }

    public func compare(to other: Self, policy: VersionPolicy = .display) -> VersionOrder {
        let lhs: String?
        let rhs: String?
        switch policy {
        case .display:
            lhs = display; rhs = other.display
        case .build:
            // The same rule applies to both sides; never choose based on lhs alone.
            if let a = build, let b = other.build { lhs = a; rhs = b }
            else { lhs = display; rhs = other.display }
        }
        guard let lhs, let rhs, let a = Self.tokens(lhs), let b = Self.tokens(rhs) else { return .unknown }
        for index in 0..<max(a.count, b.count) {
            guard index < a.count else { return b[index].isText ? .newer : .older }
            guard index < b.count else { return a[index].isText ? .older : .newer }
            if a[index] == b[index] { continue }
            switch (a[index], b[index]) {
            case (.number(let x), .number(let y)):
                return x.count == y.count ? (x < y ? .older : .newer) : (x.count < y.count ? .older : .newer)
            case (.text(let x), .text(let y)):
                let ranks = ["dev": 0, "alpha": 1, "a": 1, "beta": 2, "b": 2, "pre": 3, "rc": 4]
                if let u = ranks[x], let v = ranks[y], u != v { return u < v ? .older : .newer }
                return x < y ? .older : .newer
            case (.text, .number): return .older
            case (.number, .text): return .newer
            }
        }
        return .same
    }

    public var isPrerelease: Bool {
        guard let display else { return false }
        return display.range(of: #"(?i)(alpha|beta|preview|nightly|(?:^|[.\- ])rc\d*)"#, options: .regularExpression) != nil
    }

    private static func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private enum Token: Equatable {
        case number(String), text(String)
        var isText: Bool { if case .text = self { return true }; return false }
    }

    private static func tokens(_ value: String) -> [Token]? {
        guard value.utf8.count <= 512 else { return nil }
        var result: [Token] = []
        var current = ""
        var numeric: Bool?
        func flush() {
            guard !current.isEmpty else { return }
            if numeric == true {
                let digits = String(current.drop(while: { $0 == "0" }))
                result.append(.number(digits.isEmpty ? "0" : digits))
            } else { result.append(.text(current.lowercased())) }
            current = ""; numeric = nil
        }
        for character in value {
            if let digit = character.wholeNumberValue, digit < 10 {
                if numeric == false { flush() }
                numeric = true; current += String(digit)
            } else if character.isLetter {
                if numeric == true { flush() }
                numeric = false; current.append(character)
            } else if ".-_ ,()/".contains(character) || character.isWhitespace {
                flush()
            } else { return nil }
        }
        flush()
        if var suffixIndex = result.firstIndex(where: \.isText) {
            while suffixIndex > 1, result[suffixIndex - 1] == .number("0") {
                result.remove(at: suffixIndex - 1)
                suffixIndex -= 1
            }
        }
        // Remove only trailing zero components, never an interior zero before a nonzero component.
        while result.count > 1, result.last == .number("0") { result.removeLast() }
        guard !result.isEmpty, result.contains(where: { if case .number = $0 { true } else { false } }) else { return nil }
        return result
    }
}

public enum VersionOrder: String, Codable, Sendable { case older, same, newer, unknown }
public enum VersionPolicy: Sendable { case display, build }
