import Foundation
import Testing
@testable import QasimhaCheckout

private func plan(_ instalments: Int, frequency: String = "monthly", amount: Double = 300, sharia: Bool = true) -> PromoPlan {
    PromoPlan(instalments: instalments, frequency: frequency, instalmentAmount: amount, firstInstalmentAmount: amount,
              lastInstalmentAmount: amount, feesIncludingVat: 0, totalPayable: amount * Double(instalments), shariaCompliant: sharia)
}

@Suite struct PromoCopyTests {
    @Test(arguments: [(1, "دفعة واحدة شهرية"), (2, "دفعتين شهريتين"), (4, "4 دفعات شهرية"), (10, "10 دفعات شهرية"), (12, "12 دفعة شهرية")])
    func arabicPlanPhrases(count: Int, expected: String) {
        #expect(PromoCopy.planPhrase(.ar, instalments: count, frequency: "monthly") == expected)
    }

    @Test(arguments: [(1, "1 monthly payment"), (4, "4 monthly payments"), (12, "12 monthly payments")])
    func englishPlanPhrases(count: Int, expected: String) {
        #expect(PromoCopy.planPhrase(.en, instalments: count, frequency: "monthly") == expected)
    }

    @Test func otherFrequencies() {
        #expect(PromoCopy.planPhrase(.en, instalments: 4, frequency: "weekly") == "4 weekly payments")
        #expect(PromoCopy.planPhrase(.en, instalments: 4, frequency: "biweekly") == "4 fortnightly payments")
        #expect(PromoCopy.planPhrase(.en, instalments: 4, frequency: "unknown") == "4 payments")
        #expect(PromoCopy.planPhrase(.ar, instalments: 2, frequency: "weekly") == "دفعتين أسبوعيتين")
        #expect(PromoCopy.planPhrase(.ar, instalments: 4, frequency: "fortnightly") == "4 دفعات كل أسبوعين")
        #expect(PromoCopy.planPhrase(.ar, instalments: 4, frequency: "unknown") == "4 دفعات")
    }

    @Test func summaryEndsWithTheMoneyRun() {
        let arabic = PromoCopy.summary(.ar, plan: plan(4))
        #expect(arabic == [.text("قسّمها على 4 دفعات شهرية بقيمة "), .money(300)])
        let english = PromoCopy.summary(.en, plan: plan(4, amount: 300.5))
        #expect(english == [.text("Split into 4 monthly payments of "), .money(300.5)])
    }

    @Test func trustLineOnlyForShariaCompliantPlans() {
        #expect(PromoCopy.trustLine(.ar, plan: plan(4)) == "بدون فوائد · متوافق مع الشريعة")
        #expect(PromoCopy.trustLine(.en, plan: plan(4)) == "Interest-free · Sharia-compliant")
        #expect(PromoCopy.trustLine(.en, plan: plan(4, sharia: false)) == nil)
    }

    @Test func visibleCopyNeverNamesTheCurrency() {
        for language in [QasimhaLanguage.ar, .en] {
            var visible: [String] = [PromoCopy.wordmark(language), PromoCopy.cancel(language), PromoCopy.trustLine(language, plan: plan(4)) ?? ""]
            for segment in PromoCopy.summary(language, plan: plan(4)) {
                if case .text(let value) = segment { visible.append(value) }
            }
            for text in visible {
                #expect(!text.contains("ريال"))
                #expect(!text.contains("SAR"))
                #expect(!text.contains("SR"))
                #expect(!text.contains("\u{FDFC}"))
            }
        }
    }
}
