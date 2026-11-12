#if canImport(UIKit)
import UIKit

extension QasimhaCheckout {
    @MainActor
    public static func start(from presenter: UIViewController,
                             options: CheckoutOptions,
                             completion: @escaping (CheckoutResult) -> Void) {
        do {
            try options.validate()
        } catch {
            completion(.failure(status: CheckoutResult.Status.invalidOptions, orderId: nil, orderReferenceId: nil))
            return
        }
        guard SessionRegistry.current == nil else {
            completion(.failure(status: CheckoutResult.Status.alreadyPresenting, orderId: nil, orderReferenceId: nil))
            return
        }
        let session = CheckoutSession(presenter: presenter, options: options, completion: completion)
        SessionRegistry.register(session)
        session.start()
    }

    public static func handleReturn(url: URL) -> Bool {
        guard let session = SessionRegistry.current,
              let result = ReturnURL.parse(url, against: session.options.merchantURL) else { return false }
        session.finish(with: result)
        return true
    }
}
#endif
