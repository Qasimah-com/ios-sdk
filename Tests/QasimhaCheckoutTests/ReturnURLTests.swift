import Foundation
import Testing
@testable import QasimhaCheckout

private let sharedReturn = MerchantURL(
    success: URL(string: "https://shop.example/qasimha/return?order=1001")!,
    failure: URL(string: "https://shop.example/qasimha/return?order=1001")!,
    cancel: URL(string: "https://shop.example/cart")!
)

private let distinctReturn = MerchantURL(
    success: URL(string: "https://shop.example/qasimha/success")!,
    failure: URL(string: "https://shop.example/qasimha/failure")!,
    cancel: URL(string: "https://shop.example/qasimha/cancel")!
)

private let orderId = "9a2e6c4b-1111-4c2d-8a1f-000000000001"

private func url(_ string: String) -> URL { URL(string: string)! }

@Suite struct ReturnURLTests {
    @Test func confirmedOnSharedReturnURLIsSuccess() {
        let result = ReturnURL.parse(url("https://shop.example/qasimha/return?order=1001&orderId=\(orderId)&orderReferenceId=ORDER-1&status=confirmed"), against: sharedReturn)
        #expect(result == .success(orderId: orderId, orderReferenceId: "ORDER-1"))
    }

    @Test(arguments: ["declined", "expired", "failed"])
    func failureStatusesMapToFailure(status: String) {
        let result = ReturnURL.parse(url("https://shop.example/qasimha/return?order=1001&orderId=\(orderId)&orderReferenceId=ORDER-1&status=\(status)"), against: sharedReturn)
        #expect(result == .failure(status: status, orderId: orderId, orderReferenceId: "ORDER-1"))
    }

    @Test func cancelledStatusIsCancelled() {
        let result = ReturnURL.parse(url("https://shop.example/cart?orderId=\(orderId)&status=cancelled"), against: sharedReturn)
        #expect(result == .cancelled)
    }

    @Test func canceledSpellingIsCancelled() {
        let result = ReturnURL.parse(url("https://shop.example/cart?status=canceled"), against: sharedReturn)
        #expect(result == .cancelled)
    }

    @Test func cancelURLWithoutStatusIsCancelled() {
        #expect(ReturnURL.parse(url("https://shop.example/cart"), against: sharedReturn) == .cancelled)
    }

    @Test func successURLWithoutStatusIsUnverified() {
        let result = ReturnURL.parse(url("https://shop.example/qasimha/return?order=1001&orderId=\(orderId)"), against: sharedReturn)
        #expect(result == .failure(status: "unverified", orderId: orderId, orderReferenceId: nil))
    }

    @Test func confirmedWithoutOrderIdIsUnverified() {
        let result = ReturnURL.parse(url("https://shop.example/qasimha/return?status=confirmed"), against: sharedReturn)
        #expect(result == .failure(status: "unverified", orderId: nil, orderReferenceId: nil))
    }

    @Test func confirmedOnCancelURLIsUnverified() {
        let result = ReturnURL.parse(url("https://shop.example/qasimha/cancel?orderId=\(orderId)&status=confirmed"), against: distinctReturn)
        #expect(result == .failure(status: "unverified", orderId: orderId, orderReferenceId: nil))
    }

    @Test func failureURLWithoutStatusIsUnverified() {
        let result = ReturnURL.parse(url("https://shop.example/qasimha/failure?orderId=\(orderId)"), against: distinctReturn)
        #expect(result == .failure(status: "unverified", orderId: orderId, orderReferenceId: nil))
    }

    @Test func unknownStatusPassesThroughLowercased() {
        let result = ReturnURL.parse(url("https://shop.example/qasimha/failure?orderId=\(orderId)&status=Weird"), against: distinctReturn)
        #expect(result == .failure(status: "weird", orderId: orderId, orderReferenceId: nil))
    }

    @Test func pathBoundaryIsRespected() {
        #expect(ReturnURL.parse(url("https://shop.example/qasimha/returned?status=confirmed&orderId=\(orderId)"), against: sharedReturn) == nil)
    }

    @Test func deeperPathIsAPrefixMatch() {
        let result = ReturnURL.parse(url("https://shop.example/qasimha/return/extra?status=confirmed&orderId=\(orderId)"), against: sharedReturn)
        #expect(result == .success(orderId: orderId, orderReferenceId: nil))
    }

    @Test func trailingSlashIsIgnored() {
        let result = ReturnURL.parse(url("https://shop.example/qasimha/return/?status=confirmed&orderId=\(orderId)"), against: sharedReturn)
        #expect(result == .success(orderId: orderId, orderReferenceId: nil))
    }

    @Test func differentHostDoesNotMatch() {
        #expect(ReturnURL.parse(url("https://evil.example/qasimha/return?status=confirmed&orderId=\(orderId)"), against: sharedReturn) == nil)
    }

    @Test func differentSchemeDoesNotMatch() {
        #expect(ReturnURL.parse(url("http://shop.example/qasimha/return?status=confirmed&orderId=\(orderId)"), against: sharedReturn) == nil)
    }

    @Test func schemeAndHostAreCaseInsensitive() {
        let result = ReturnURL.parse(url("HTTPS://SHOP.EXAMPLE/qasimha/return?status=confirmed&orderId=\(orderId)"), against: sharedReturn)
        #expect(result == .success(orderId: orderId, orderReferenceId: nil))
    }

    @Test func explicitDefaultPortMatches() {
        let result = ReturnURL.parse(url("https://shop.example:443/qasimha/return?status=confirmed&orderId=\(orderId)"), against: sharedReturn)
        #expect(result == .success(orderId: orderId, orderReferenceId: nil))
    }

    @Test func otherPortDoesNotMatch() {
        #expect(ReturnURL.parse(url("https://shop.example:8443/qasimha/return?status=confirmed&orderId=\(orderId)"), against: sharedReturn) == nil)
    }

    @Test func customSchemeReturn() {
        let merchant = MerchantURL(success: url("myshop://qasimha/return"), failure: url("myshop://qasimha/return"), cancel: url("myshop://qasimha/cancel"))
        let result = ReturnURL.parse(url("myshop://qasimha/return?orderId=\(orderId)&orderReferenceId=ORDER-1&status=confirmed"), against: merchant)
        #expect(result == .success(orderId: orderId, orderReferenceId: "ORDER-1"))
        #expect(ReturnURL.parse(url("myshop://qasimha/cancel"), against: merchant) == .cancelled)
        #expect(ReturnURL.parse(url("other://qasimha/return?status=confirmed&orderId=\(orderId)"), against: merchant) == nil)
    }

    @Test func percentEncodedReferenceIsDecoded() {
        let result = ReturnURL.parse(url("https://shop.example/qasimha/return?status=confirmed&orderId=\(orderId)&orderReferenceId=ORDER%20%231"), against: sharedReturn)
        #expect(result == .success(orderId: orderId, orderReferenceId: "ORDER #1"))
    }

    @Test func emptyParametersAreTreatedAsAbsent() {
        let result = ReturnURL.parse(url("https://shop.example/qasimha/return?status=confirmed&orderId=&orderReferenceId="), against: sharedReturn)
        #expect(result == .failure(status: "unverified", orderId: nil, orderReferenceId: nil))
    }

    @Test func unrelatedURLIsNil() {
        #expect(ReturnURL.parse(url("https://pay.example/pay/abc"), against: sharedReturn) == nil)
    }

    @Test func rootTargetMatchesAnyPath() {
        let merchant = MerchantURL(success: url("myshop://qasimha"), failure: url("myshop://qasimha"), cancel: url("myshop://qasimha"))
        let result = ReturnURL.parse(url("myshop://qasimha/anything?status=confirmed&orderId=\(orderId)"), against: merchant)
        #expect(result == .success(orderId: orderId, orderReferenceId: nil))
    }
}
