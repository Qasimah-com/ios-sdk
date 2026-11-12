import Foundation

public enum CheckoutResult: Equatable, Sendable {
    case success(orderId: String, orderReferenceId: String?)
    case failure(status: String, orderId: String?, orderReferenceId: String?)
    case cancelled

    public enum Status {
        public static let confirmed = "confirmed"
        public static let declined = "declined"
        public static let expired = "expired"
        public static let failed = "failed"
        public static let cancelled = "cancelled"
        public static let unverified = "unverified"
        public static let invalidOptions = "invalid_options"
        public static let alreadyPresenting = "already_presenting"
    }
}
