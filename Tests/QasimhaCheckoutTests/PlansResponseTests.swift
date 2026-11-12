import Foundation
import Testing
@testable import QasimhaCheckout

private func envelope(_ data: String, success: String = "true") -> Data {
    Data("{\"success\": \(success), \"code\": \"OK\", \"data\": \(data)}".utf8)
}

private let fullPlan = """
{"instalments": 4, "frequency": "monthly", "instalmentAmount": 300, "firstInstalmentAmount": 300, "lastInstalmentAmount": 300, "feesIncludingVat": 0, "totalPayable": 1200, "shariaCompliant": true}
"""

private func payload(plans: String, currency: String = "SAR", min: String = "100", max: String = "20000") -> String {
    "{\"merchantName\": \"Demo Store\", \"currency\": \"\(currency)\", \"minAmount\": \(min), \"maxAmount\": \(max), \"plans\": [\(plans)]}"
}

@Suite struct PlansResponseTests {
    @Test func decodesTheDocumentedEnvelope() throws {
        let plans = try #require(PlansResponse.parse(envelope(payload(plans: fullPlan)), amount: 1200))
        #expect(plans.merchantName == "Demo Store")
        #expect(plans.minAmount == 100 && plans.maxAmount == 20000)
        #expect(plans.plans == [PromoPlan(instalments: 4, frequency: "monthly", instalmentAmount: 300, firstInstalmentAmount: 300,
                                          lastInstalmentAmount: 300, feesIncludingVat: 0, totalPayable: 1200, shariaCompliant: true)])
    }

    @Test func successMustBeTheBooleanTrue() {
        #expect(PlansResponse.parse(envelope(payload(plans: fullPlan), success: "false"), amount: 1200) == nil)
        #expect(PlansResponse.parse(envelope(payload(plans: fullPlan), success: "1"), amount: 1200) == nil)
        #expect(PlansResponse.parse(envelope(payload(plans: fullPlan), success: "\"true\""), amount: 1200) == nil)
    }

    @Test func currencyMustBeSAR() {
        #expect(PlansResponse.parse(envelope(payload(plans: fullPlan, currency: "USD")), amount: 1200) == nil)
    }

    @Test func amountMustBeWithinTheMerchantRange() {
        #expect(PlansResponse.parse(envelope(payload(plans: fullPlan)), amount: 99.99) == nil)
        #expect(PlansResponse.parse(envelope(payload(plans: fullPlan)), amount: 20000.01) == nil)
        #expect(PlansResponse.parse(envelope(payload(plans: fullPlan)), amount: 100) != nil)
        #expect(PlansResponse.parse(envelope(payload(plans: fullPlan)), amount: 20000) != nil)
    }

    @Test func emptyOrMissingPlansIsNothing() {
        #expect(PlansResponse.parse(envelope(payload(plans: "")), amount: 1200) == nil)
        #expect(PlansResponse.parse(envelope("{\"currency\": \"SAR\", \"minAmount\": 100, \"maxAmount\": 20000}"), amount: 1200) == nil)
        #expect(PlansResponse.parse(envelope("null"), amount: 1200) == nil)
    }

    @Test func malformedPlansAreSkipped() throws {
        let plans = try #require(PlansResponse.parse(envelope(payload(plans: "\"junk\", {\"instalments\": \"four\"}, \(fullPlan)")), amount: 1200))
        #expect(plans.plans.count == 1)
    }

    @Test func optionalPlanFieldsDefault() throws {
        let plans = try #require(PlansResponse.parse(envelope(payload(plans: "{\"instalments\": 3, \"instalmentAmount\": 400, \"totalPayable\": 1200}")), amount: 1200))
        let plan = try #require(plans.plans.first)
        #expect(plan.frequency == "monthly")
        #expect(plan.firstInstalmentAmount == 400 && plan.lastInstalmentAmount == 400)
        #expect(plan.feesIncludingVat == 0)
        #expect(plan.shariaCompliant == false)
    }

    @Test(arguments: [
        "{\"instalments\": 0, \"instalmentAmount\": 1, \"totalPayable\": 1}",
        "{\"instalments\": 61, \"instalmentAmount\": 1, \"totalPayable\": 1}",
        "{\"instalments\": 4, \"instalmentAmount\": -1, \"totalPayable\": 1}",
        "{\"instalments\": 4, \"instalmentAmount\": 1}",
        "{\"instalments\": 4, \"instalmentAmount\": \"300\", \"totalPayable\": 1200}",
        "{\"instalments\": 4, \"instalmentAmount\": 300, \"totalPayable\": 1200, \"feesIncludingVat\": -5}",
    ])
    func invalidPlansAreRejected(plan: String) {
        #expect(PlansResponse.parse(envelope(payload(plans: plan)), amount: 1200) == nil)
    }

    @Test func invalidJSONIsNothing() {
        #expect(PlansResponse.parse(Data("not json".utf8), amount: 1200) == nil)
        #expect(PlansResponse.parse(Data(), amount: 1200) == nil)
        #expect(PlansResponse.parse(Data("[]".utf8), amount: 1200) == nil)
    }
}
