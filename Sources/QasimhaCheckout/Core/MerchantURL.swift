import Foundation

public struct MerchantURL: Equatable, Sendable {
    public let success: URL
    public let failure: URL
    public let cancel: URL

    public init(success: URL, failure: URL, cancel: URL? = nil) {
        self.success = success
        self.failure = failure
        self.cancel = cancel ?? failure
    }

    public enum Issue: String, Equatable, Sendable {
        case notAbsolute
        case tooLong
        case hasFragment
        case missingHost
        case insecureScheme
        case forbiddenScheme
        case schemeTooShort
    }

    public static let maxLength = 1024
    static let localHosts: Set<String> = ["localhost", "127.0.0.1", "::1"]

    public static func validate(_ url: URL) -> Issue? {
        if url.absoluteString.count > maxLength { return .tooLong }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let scheme = components.scheme?.lowercased(), !scheme.isEmpty else { return .notAbsolute }
        if components.fragment != nil { return .hasFragment }
        let host = (components.host ?? "").lowercased()
        switch scheme {
        case "https":
            return host.isEmpty ? .missingHost : nil
        case "http":
            if host.isEmpty { return .missingHost }
            return localHosts.contains(host) ? nil : .insecureScheme
        case "javascript", "data", "file", "blob", "vbscript":
            return .forbiddenScheme
        default:
            if scheme.count < 3 { return .schemeTooShort }
            return (host.isEmpty && components.path.isEmpty) ? .missingHost : nil
        }
    }

    var fields: [(name: String, url: URL)] {
        [("success", success), ("failure", failure), ("cancel", cancel)]
    }
}
