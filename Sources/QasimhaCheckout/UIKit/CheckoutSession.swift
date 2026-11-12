#if canImport(UIKit)
import UIKit
import SafariServices
import AuthenticationServices

@MainActor
final class CheckoutSession {
    nonisolated let options: CheckoutOptions

    private let completion: (CheckoutResult) -> Void
    private weak var presenter: UIViewController?
    private var presented: UIViewController?
    private var authSession: ASWebAuthenticationSession?
    private var safariBridge: SafariBridge?
    private var anchorProvider: AnchorProvider?
    private var finished = false

    init(presenter: UIViewController, options: CheckoutOptions, completion: @escaping (CheckoutResult) -> Void) {
        self.presenter = presenter
        self.options = options
        self.completion = completion
    }

    func start() {
        switch options.presentation {
        case .safariViewController:
            startSafari()
        case .webAuthenticationSession(let callbackScheme):
            startAuthenticationSession(callbackScheme: callbackScheme)
        case .webView:
            startWebView()
        }
    }

    nonisolated func finish(with result: CheckoutResult) {
        DispatchQueue.main.async { self.finishOnMain(result) }
    }

    nonisolated func presentedControllerWasDismissed() {
        DispatchQueue.main.async { self.presentedControllerDidDismiss() }
    }

    func finishOnMain(_ result: CheckoutResult) {
        guard !finished else { return }
        finished = true
        SessionRegistry.clear(self)
        authSession?.cancel()
        authSession = nil
        let completion = self.completion
        if let presented = presented, presented.presentingViewController != nil {
            self.presented = nil
            presented.dismiss(animated: true) { completion(result) }
        } else {
            presented = nil
            completion(result)
        }
    }

    func presentedControllerDidDismiss() {
        presented = nil
        finishOnMain(.cancelled)
    }

    private var presentingController: UIViewController? {
        var top = presenter
        while let next = top?.presentedViewController { top = next }
        return top
    }

    private func present(_ controller: UIViewController) {
        guard let host = presentingController else {
            finishOnMain(.cancelled)
            return
        }
        presented = controller
        host.present(controller, animated: true)
    }

    private func startSafari() {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        let controller = SFSafariViewController(url: options.launchURL, configuration: configuration)
        controller.dismissButtonStyle = .cancel
        let bridge = SafariBridge(session: self)
        safariBridge = bridge
        controller.delegate = bridge
        present(controller)
    }

    private func startAuthenticationSession(callbackScheme: String) {
        let session = ASWebAuthenticationSession(url: options.launchURL, callbackURLScheme: callbackScheme) { [weak self] callbackURL, _ in
            guard let self = self else { return }
            if let url = callbackURL, let result = ReturnURL.parse(url, against: self.options.merchantURL) {
                self.finish(with: result)
            } else {
                self.finish(with: .cancelled)
            }
        }
        let provider = AnchorProvider(window: presenter?.view.window)
        anchorProvider = provider
        session.presentationContextProvider = provider
        session.prefersEphemeralWebBrowserSession = true
        authSession = session
        if !session.start() {
            finishOnMain(.cancelled)
        }
    }

    private func startWebView() {
        let controller = CheckoutWebViewController(options: options) { [weak self] result in
            self?.finishOnMain(result)
        }
        let navigation = UINavigationController(rootViewController: controller)
        navigation.isModalInPresentation = true
        navigation.presentationController?.delegate = controller
        present(navigation)
    }
}

final class SafariBridge: NSObject, SFSafariViewControllerDelegate {
    private weak var session: CheckoutSession?

    init(session: CheckoutSession) {
        self.session = session
    }

    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        session?.presentedControllerWasDismissed()
    }

    func safariViewController(_ controller: SFSafariViewController, initialLoadDidRedirectTo url: URL) {
        guard let session = session, let result = ReturnURL.parse(url, against: session.options.merchantURL) else { return }
        session.finish(with: result)
    }
}

@MainActor
final class AnchorProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    private weak var window: UIWindow?

    init(window: UIWindow?) {
        self.window = window
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        window ?? ASPresentationAnchor()
    }
}
#endif
