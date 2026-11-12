#if canImport(UIKit)
import UIKit
import WebKit

@MainActor
final class CheckoutWebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, UIAdaptivePresentationControllerDelegate {
    private let options: CheckoutOptions
    private let onResult: (CheckoutResult) -> Void
    private let allowedHosts: Set<String>
    private var webView: WKWebView!
    private var delivered = false

    init(options: CheckoutOptions, onResult: @escaping (CheckoutResult) -> Void) {
        self.options = options
        self.onResult = onResult
        self.allowedHosts = options.allowedHosts
        super.init(nibName: nil, bundle: nil)
        let language = options.resolvedLanguage
        title = PromoCopy.wordmark(language)
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: PromoCopy.cancel(language), style: .plain, target: self, action: #selector(cancelTapped))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController = WKUserContentController()
        configuration.processPool = WKProcessPool()
        configuration.dataDetectorTypes = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsLinkPreview = false
        webView.allowsBackForwardNavigationGestures = false
        self.webView = webView
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        webView.load(URLRequest(url: options.launchURL, cachePolicy: .reloadIgnoringLocalCacheData))
    }

    @objc private func cancelTapped() {
        deliver(.cancelled)
    }

    private func deliver(_ result: CheckoutResult) {
        guard !delivered else { return }
        delivered = true
        webView.stopLoading()
        onResult(result)
    }

    private func policy(for url: URL?) -> WKNavigationActionPolicy {
        guard let url = url else { return .cancel }
        if let result = ReturnURL.parse(url, against: options.merchantURL) {
            deliver(result)
            return .cancel
        }
        let scheme = url.scheme?.lowercased() ?? ""
        let host = (URLComponents(url: url, resolvingAgainstBaseURL: true)?.host ?? "").lowercased()
        switch scheme {
        case "https":
            return allowedHosts.contains(host) ? .allow : .cancel
        case "http":
            return MerchantURL.localHosts.contains(host) && allowedHosts.contains(host) ? .allow : .cancel
        case "about":
            return url.absoluteString == "about:blank" ? .allow : .cancel
        default:
            return .cancel
        }
    }

    private func handle(_ error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
        if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 { return }
        deliver(.cancelled)
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        deliver(.cancelled)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(policy(for: navigationAction.request.url))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handle(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handle(error)
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            completionHandler(.performDefaultHandling, nil)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        deliver(.cancelled)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame?.isMainFrame != true, policy(for: navigationAction.request.url) == .allow {
            webView.load(navigationAction.request)
        }
        return nil
    }
}
#endif
