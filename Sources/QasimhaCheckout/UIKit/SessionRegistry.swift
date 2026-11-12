#if canImport(UIKit)
import Foundation

final class SessionRegistry {
    private static let lock = NSLock()
    private static var active: CheckoutSession?

    static var current: CheckoutSession? {
        lock.lock()
        defer { lock.unlock() }
        return active
    }

    static func register(_ session: CheckoutSession) {
        lock.lock()
        active = session
        lock.unlock()
    }

    static func clear(_ session: CheckoutSession) {
        lock.lock()
        if active === session { active = nil }
        lock.unlock()
    }
}
#endif
