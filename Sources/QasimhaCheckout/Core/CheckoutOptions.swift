import Foundation

public enum Presentation: Equatable, Sendable {
    case safariViewController
    case webAuthenticationSession(callbackScheme: String)
    case webView
}

public struct WebViewPolicy: Equatable, Sendable {
    public var extraAllowedHosts: [String]

    public init(extraAllowedHosts: [String] = []) {
        self.extraAllowedHosts = extraAllowedHosts
    }
}

public enum CheckoutOptionsError: Error, Equatable {
    case invalidPaymentURL
    case invalidMerchantURL(field: String, issue: MerchantURL.Issue)
    case invalidCallbackScheme
    case invalidAllowedHost(String)
}

public struct CheckoutOptions: Equatable, Sendable {
    public let paymentURL: URL
    public let merchantURL: MerchantURL
    public var presentation: Presentation
    public var language: String
    public var webView: WebViewPolicy

    public init(paymentURL: URL,
                merchantURL: MerchantURL,
                presentation: Presentation = .safariViewController,
                language: String = "ar") {
        self.paymentURL = paymentURL
        self.merchantURL = merchantURL
        self.presentation = presentation
        self.language = language
        self.webView = WebViewPolicy()
    }

    public var resolvedLanguage: QasimhaLanguage { QasimhaLanguage.resolve(language) }

    public var launchURL: URL {
        guard var components = URLComponents(url: paymentURL, resolvingAgainstBaseURL: true) else { return paymentURL }
        var items = components.queryItems ?? []
        if !items.contains(where: { $0.name == "lang" }) {
            items.append(URLQueryItem(name: "lang", value: resolvedLanguage.rawValue))
        }
        components.queryItems = items
        return components.url ?? paymentURL
    }

    public func validate() throws {
        guard let components = URLComponents(url: paymentURL, resolvingAgainstBaseURL: true),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(), !host.isEmpty,
              scheme == "https" || (scheme == "http" && MerchantURL.localHosts.contains(host)) else {
            throw CheckoutOptionsError.invalidPaymentURL
        }
        for field in merchantURL.fields {
            if let issue = MerchantURL.validate(field.url) {
                throw CheckoutOptionsError.invalidMerchantURL(field: field.name, issue: issue)
            }
        }
        if case .webAuthenticationSession(let callbackScheme) = presentation {
            let scheme = callbackScheme.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !scheme.isEmpty, scheme != "http", scheme != "https",
                  merchantURL.fields.contains(where: { $0.url.scheme?.lowercased() == scheme }) else {
                throw CheckoutOptionsError.invalidCallbackScheme
            }
        }
        for host in webView.extraAllowedHosts {
            let value = host.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, value.rangeOfCharacter(from: CheckoutOptions.hostForbidden) == nil else {
                throw CheckoutOptionsError.invalidAllowedHost(host)
            }
        }
    }

    public var allowedHosts: Set<String> {
        var hosts = Set<String>()
        let urls = [paymentURL] + merchantURL.fields.map { $0.url }
        for url in urls {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                  let scheme = components.scheme?.lowercased(), scheme == "https" || scheme == "http",
                  let host = components.host?.lowercased(), !host.isEmpty else { continue }
            hosts.insert(host)
        }
        for host in webView.extraAllowedHosts {
            let value = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !value.isEmpty { hosts.insert(value) }
        }
        return hosts
    }

    private static let hostForbidden = CharacterSet(charactersIn: "/\\?#@: ").union(.whitespacesAndNewlines).union(.controlCharacters)
}
