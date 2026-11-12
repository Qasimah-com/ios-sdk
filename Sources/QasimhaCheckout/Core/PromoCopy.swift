import Foundation

public enum PromoSegment: Equatable, Sendable {
    case text(String)
    case money(Double)
}

public enum PromoCopy {
    public static func wordmark(_ language: QasimhaLanguage) -> String {
        language == .ar ? "قسّمها" : "Qasimha"
    }

    public static func planPhrase(_ language: QasimhaLanguage, instalments count: Int, frequency: String) -> String {
        let frequency = frequency.lowercased()
        switch language {
        case .en:
            let word: String
            switch frequency {
            case "monthly": word = "monthly "
            case "weekly": word = "weekly "
            case "biweekly", "fortnightly": word = "fortnightly "
            default: word = ""
            }
            return "\(count) \(word)" + (count == 1 ? "payment" : "payments")
        case .ar:
            var unit = ""
            switch frequency {
            case "monthly": unit = count == 2 ? "شهريتين" : "شهرية"
            case "weekly": unit = count == 2 ? "أسبوعيتين" : "أسبوعية"
            case "biweekly", "fortnightly": unit = "كل أسبوعين"
            default: break
            }
            let suffix = unit.isEmpty ? "" : " " + unit
            if count == 1 { return "دفعة واحدة" + suffix }
            if count == 2 { return "دفعتين" + suffix }
            if count <= 10 { return "\(count) دفعات" + suffix }
            return "\(count) دفعة" + suffix
        }
    }

    public static func summary(_ language: QasimhaLanguage, plan: PromoPlan) -> [PromoSegment] {
        let phrase = planPhrase(language, instalments: plan.instalments, frequency: plan.frequency)
        switch language {
        case .ar: return [.text("قسّمها على " + phrase + " بقيمة "), .money(plan.instalmentAmount)]
        case .en: return [.text("Split into " + phrase + " of "), .money(plan.instalmentAmount)]
        }
    }

    public static func trustLine(_ language: QasimhaLanguage, plan: PromoPlan) -> String? {
        guard plan.shariaCompliant else { return nil }
        return language == .ar ? "بدون فوائد · متوافق مع الشريعة" : "Interest-free · Sharia-compliant"
    }

    public static func cancel(_ language: QasimhaLanguage) -> String {
        language == .ar ? "إلغاء" : "Cancel"
    }

    public static func moneyAccessibilityLabel(_ language: QasimhaLanguage, _ value: Double) -> String {
        let number = Money.format(value)
        return language == .ar ? number + " ريال" : "SAR " + number
    }
}
