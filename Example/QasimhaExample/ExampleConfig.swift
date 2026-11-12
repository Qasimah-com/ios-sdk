import Foundation
import QasimhaCheckout

enum ExampleConfig {
    static let publicKey = "pk_test_example"
    static let callbackScheme = "qasimhaexample"
    static let merchantServer = URL(string: "http://localhost:4311")!
    static let merchantURL = MerchantURL(
        success: URL(string: "qasimhaexample://checkout/return")!,
        failure: URL(string: "qasimhaexample://checkout/return")!,
        cancel: URL(string: "qasimhaexample://checkout/cancel")!
    )
}
