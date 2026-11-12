import Foundation
import Testing
@testable import QasimhaCheckout

private func options(payment: String = "https://pay.example/pay/abc",
                     success: String = "https://shop.example/qasimha/return",
                     failure: String = "https://shop.example/qasimha/return",
                     cancel: String? = "https://shop.example/cart",
                     presentation: Presentation = .safariViewController,
                     language: String = "ar") -> CheckoutOptions {
    CheckoutOptions(paymentURL: URL(string: payment)!,
                    merchantURL: MerchantURL(success: URL(string: success)!, failure: URL(string: failure)!, cancel: cancel.map { URL(string: $0)! }),
                    presentation: presentation,
                    language: language)
}

@Suite struct CheckoutOptionsTests {
    @Test func validOptionsPass() throws {
        try options().validate()
        try options(presentation: .webView).validate()
    }

    @Test func httpPaymentURLIsRejected() {
        #expect(throws: CheckoutOptionsError.invalidPaymentURL) { try options(payment: "http://pay.example/pay/abc").validate() }
    }

    @Test func localhostHTTPIsAllowedForDevelopment() throws {
        try options(payment: "http://localhost:4310/pay/abc", success: "http://127.0.0.1:3000/return", failure: "http://127.0.0.1:3000/return", cancel: nil).validate()
    }

    @Test func fragmentIsRejected() {
        #expect(throws: CheckoutOptionsError.invalidMerchantURL(field: "success", issue: .hasFragment)) {
            try options(success: "https://shop.example/return#top").validate()
        }
    }

    @Test func overlongURLIsRejected() {
        let long = "https://shop.example/" + String(repeating: "a", count: 1010)
        #expect(throws: CheckoutOptionsError.invalidMerchantURL(field: "failure", issue: .tooLong)) {
            try options(failure: long).validate()
        }
    }

    @Test func insecureHTTPMerchantURLIsRejected() {
        #expect(throws: CheckoutOptionsError.invalidMerchantURL(field: "cancel", issue: .insecureScheme)) {
            try options(cancel: "http://shop.example/cart").validate()
        }
    }

    @Test(arguments: ["javascript:alert(1)", "data:text/html,hi", "file:///etc/passwd", "blob:abc", "vbscript:x"])
    func forbiddenSchemesAreRejected(value: String) {
        #expect(throws: CheckoutOptionsError.invalidMerchantURL(field: "success", issue: .forbiddenScheme)) {
            try options(success: value).validate()
        }
    }

    @Test func shortCustomSchemeIsRejected() {
        #expect(throws: CheckoutOptionsError.invalidMerchantURL(field: "success", issue: .schemeTooShort)) {
            try options(success: "ab://return").validate()
        }
    }

    @Test func customSchemeIsAccepted() throws {
        try options(success: "myshop://qasimha/return", failure: "myshop://qasimha/return", cancel: "myshop://qasimha/cancel").validate()
    }

    @Test func cancelDefaultsToFailure() {
        let merchant = MerchantURL(success: URL(string: "https://shop.example/ok")!, failure: URL(string: "https://shop.example/failed")!)
        #expect(merchant.cancel == merchant.failure)
    }

    @Test func callbackSchemeMustBelongToAMerchantURL() throws {
        try options(success: "myshop://qasimha/return", failure: "myshop://qasimha/return", cancel: "myshop://qasimha/cancel",
                    presentation: .webAuthenticationSession(callbackScheme: "myshop")).validate()
        #expect(throws: CheckoutOptionsError.invalidCallbackScheme) {
            try options(presentation: .webAuthenticationSession(callbackScheme: "myshop")).validate()
        }
        #expect(throws: CheckoutOptionsError.invalidCallbackScheme) {
            try options(presentation: .webAuthenticationSession(callbackScheme: "https")).validate()
        }
        #expect(throws: CheckoutOptionsError.invalidCallbackScheme) {
            try options(presentation: .webAuthenticationSession(callbackScheme: "")).validate()
        }
    }

    @Test func extraAllowedHostsAreValidated() {
        var value = options(presentation: .webView)
        value.webView.extraAllowedHosts = ["psp.example/"]
        #expect(throws: CheckoutOptionsError.invalidAllowedHost("psp.example/")) { try value.validate() }
        value.webView.extraAllowedHosts = ["PSP.example"]
        #expect(value.allowedHosts.contains("psp.example"))
    }

    @Test(arguments: [("ar", QasimhaLanguage.ar), ("EN", .en), ("en-US", .en), ("en_GB", .en), ("fr", .ar), ("", .ar)])
    func languageIsNormalized(raw: String, expected: QasimhaLanguage) {
        #expect(options(language: raw).resolvedLanguage == expected)
    }

    @Test func launchURLAppendsLanguage() {
        #expect(options().launchURL.absoluteString == "https://pay.example/pay/abc?lang=ar")
        #expect(options(payment: "https://pay.example/pay/abc?x=1", language: "en").launchURL.absoluteString == "https://pay.example/pay/abc?x=1&lang=en")
        #expect(options(payment: "https://pay.example/pay/abc?lang=en", language: "ar").launchURL.absoluteString == "https://pay.example/pay/abc?lang=en")
    }

    @Test func allowedHostsCoverPaymentAndReturnHosts() {
        let value = options(cancel: "myshop://qasimha/cancel")
        #expect(value.allowedHosts == ["pay.example", "shop.example"])
    }
}
