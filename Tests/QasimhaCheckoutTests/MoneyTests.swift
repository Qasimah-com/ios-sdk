import Foundation
import Testing
@testable import QasimhaCheckout

@Suite struct MoneyTests {
    @Test(arguments: [
        (1200.0, "1,200"), (300.5, "300.50"), (0.05, "0.05"), (1234567.89, "1,234,567.89"),
        (0.0, "0"), (999.999, "1,000"), (100.0, "100"), (1000.0, "1,000"), (12.1, "12.10"), (-25.5, "-25.50"),
    ])
    func formatsDoubles(value: Double, expected: String) {
        #expect(Money.format(value) == expected)
    }

    @Test func formatsDecimals() {
        #expect(Money.format(Decimal(string: "1200.10")!) == "1,200.10")
        #expect(Money.format(Decimal(string: "1200")!) == "1,200")
        #expect(Money.format(Decimal(string: "0.5")!) == "0.50")
    }

    @Test func nonFiniteDoublesFormatToNothing() {
        #expect(Money.format(Double.nan) == "")
        #expect(Money.format(Double.infinity) == "")
    }

    @Test(arguments: [("1200", "1200.00"), ("300.5", "300.50"), ("0.01", "0.01"), ("999999999.99", "999999999.99")])
    func amountParameterHasTwoDecimals(raw: String, expected: String) {
        #expect(Money.amountParameter(Decimal(string: raw)!) == expected)
    }

    @Test(arguments: ["0", "-1", "1.005", "1000000000", "12.345"])
    func invalidAmountsHaveNoParameter(raw: String) {
        #expect(Money.amountParameter(Decimal(string: raw)!) == nil)
    }
}
