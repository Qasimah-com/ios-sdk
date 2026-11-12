import Foundation

public enum QasimhaEnvironment {
    public static let productionAPI = URL(string: "https://api.qasimha.com")!
    public static let sandboxAPI = URL(string: "https://api-uat.qasimha.com")!

    public static func normalizedAPIBaseURL(_ url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(), !host.isEmpty else { return nil }
        guard scheme == "https" || (scheme == "http" && MerchantURL.localHosts.contains(host)) else { return nil }
        guard components.user == nil, components.password == nil else { return nil }
        components.scheme = scheme
        components.host = host
        components.query = nil
        components.fragment = nil
        var path = components.path
        while path.hasSuffix("/") { path.removeLast() }
        components.path = path
        return components.url
    }
}

public struct PublicKey: Equatable, Sendable {
    public let rawValue: String
    public let isLive: Bool

    public init?(_ raw: String) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let live: Bool
        if value.hasPrefix("pk_live_") {
            live = true
        } else if value.hasPrefix("pk_test_") {
            live = false
        } else {
            return nil
        }
        let suffix = value.dropFirst("pk_live_".count)
        guard !suffix.isEmpty, suffix.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return nil }
        rawValue = value
        isLive = live
    }

    public var apiBaseURL: URL { isLive ? QasimhaEnvironment.productionAPI : QasimhaEnvironment.sandboxAPI }

    public var masked: String { "pk_" + (isLive ? "live" : "test") + "_…" + rawValue.suffix(4) }
}
