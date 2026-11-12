import Foundation

public enum ReturnURL {
    struct Normalized: Equatable {
        let scheme: String
        let host: String
        let port: Int?
        let path: String

        init?(_ url: URL) {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                  let scheme = components.scheme?.lowercased(), !scheme.isEmpty else { return nil }
            self.scheme = scheme
            host = (components.host ?? "").lowercased()
            port = components.port ?? Normalized.defaultPort(for: scheme)
            var path = components.path
            while path.hasSuffix("/") { path.removeLast() }
            self.path = path
        }

        static func defaultPort(for scheme: String) -> Int? {
            switch scheme {
            case "https": return 443
            case "http": return 80
            default: return nil
            }
        }

        func isPrefix(of candidate: Normalized) -> Bool {
            guard scheme == candidate.scheme, host == candidate.host, port == candidate.port else { return false }
            if path.isEmpty { return true }
            return candidate.path == path || candidate.path.hasPrefix(path + "/")
        }
    }

    public static func matches(_ url: URL, _ target: URL) -> Bool {
        guard let candidate = Normalized(url), let target = Normalized(target) else { return false }
        return target.isPrefix(of: candidate)
    }

    public static func queryParameters(of url: URL) -> [String: String] {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems else { return [:] }
        var result: [String: String] = [:]
        for item in items where result[item.name] == nil {
            let value = (item.value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { result[item.name] = value }
        }
        return result
    }

    public static func parse(_ url: URL, against merchantURL: MerchantURL) -> CheckoutResult? {
        let matchedSuccess = matches(url, merchantURL.success)
        let matchedFailure = matches(url, merchantURL.failure)
        let matchedCancel = matches(url, merchantURL.cancel)
        guard matchedSuccess || matchedFailure || matchedCancel else { return nil }

        let query = queryParameters(of: url)
        let orderId = query["orderId"]
        let reference = query["orderReferenceId"]
        let status = query["status"]?.lowercased()

        switch status {
        case CheckoutResult.Status.confirmed?:
            if matchedSuccess, let orderId = orderId {
                return .success(orderId: orderId, orderReferenceId: reference)
            }
            return .failure(status: CheckoutResult.Status.unverified, orderId: orderId, orderReferenceId: reference)
        case "cancelled"?, "canceled"?:
            return .cancelled
        case let value? where !value.isEmpty:
            return .failure(status: value, orderId: orderId, orderReferenceId: reference)
        default:
            if matchedCancel && !matchedSuccess && !matchedFailure { return .cancelled }
            return .failure(status: CheckoutResult.Status.unverified, orderId: orderId, orderReferenceId: reference)
        }
    }
}
