import Foundation
import Testing
@testable import QasimhaCheckout

@Suite struct PublicKeyTests {
    @Test func liveKeysUseTheProductionHost() throws {
        let key = try #require(PublicKey("pk_live_AbC123"))
        #expect(key.isLive)
        #expect(key.apiBaseURL.absoluteString == "https://api.qasimha.com")
        #expect(key.masked == "pk_live_…C123")
    }

    @Test func testKeysUseTheSandboxHost() throws {
        let key = try #require(PublicKey(" pk_test_xyz789 "))
        #expect(!key.isLive)
        #expect(key.rawValue == "pk_test_xyz789")
        #expect(key.apiBaseURL.absoluteString == "https://api-uat.qasimha.com")
    }

    @Test(arguments: ["", "pk_", "pk_test_", "sk_test_abc", "pk_live_ab-c", "pk_live_ab c", "PK_TEST_abc", "pk_test_abc_def", "pk_test_ábc"])
    func malformedKeysAreRejected(raw: String) {
        #expect(PublicKey(raw) == nil)
    }

    @Test func plansRequestIsExact() throws {
        let key = try #require(PublicKey("pk_test_abc"))
        let request = try #require(PlansClient.request(amount: 1200, publicKey: key, language: .ar))
        #expect(request.url?.absoluteString == "https://api-uat.qasimha.com/api/v1/widget/plans?amount=1200.00&currency=SAR&lang=ar")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "X-Public-Key") == "pk_test_abc")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "qasimha-checkout-ios/" + QasimhaCheckout.version)
        #expect(request.httpShouldHandleCookies == false)
        #expect(request.timeoutInterval == 5)
        #expect(request.cachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
    }

    @Test func liveRequestUsesProductionAndEnglish() throws {
        let key = try #require(PublicKey("pk_live_abc"))
        let request = try #require(PlansClient.request(amount: Decimal(string: "300.5")!, publicKey: key, language: .en))
        #expect(request.url?.absoluteString == "https://api.qasimha.com/api/v1/widget/plans?amount=300.50&currency=SAR&lang=en")
    }

    @Test func invalidAmountProducesNoRequest() throws {
        let key = try #require(PublicKey("pk_test_abc"))
        #expect(PlansClient.request(amount: 0, publicKey: key, language: .ar) == nil)
        #expect(PlansClient.request(amount: Decimal(string: "1.005")!, publicKey: key, language: .ar) == nil)
    }

    @Test func baseURLOverrideMustBeTLSOrLocal() throws {
        let key = try #require(PublicKey("pk_test_abc"))
        #expect(PlansClient.request(amount: 100, publicKey: key, apiBaseURL: URL(string: "http://staging.example")!, language: .ar) == nil)
        #expect(PlansClient.request(amount: 100, publicKey: key, apiBaseURL: URL(string: "https://user:pw@staging.example")!, language: .ar) == nil)
        let local = try #require(PlansClient.request(amount: 100, publicKey: key, apiBaseURL: URL(string: "http://localhost:4310/")!, language: .ar))
        #expect(local.url?.absoluteString == "http://localhost:4310/api/v1/widget/plans?amount=100.00&currency=SAR&lang=ar")
        let prefixed = try #require(PlansClient.request(amount: 100, publicKey: key, apiBaseURL: URL(string: "HTTPS://Staging.Example/prefix/?x=1#f")!, language: .en))
        #expect(prefixed.url?.absoluteString == "https://staging.example/prefix/api/v1/widget/plans?amount=100.00&currency=SAR&lang=en")
    }
}
