import Foundation

public enum Money {
    public static let maxAmount = Decimal(string: "999999999.99")!

    public static func format(_ value: Double) -> String {
        guard value.isFinite else { return "" }
        let scaled = (abs(value) * 100).rounded()
        guard scaled < 1e15 else { return "" }
        return formatHalalas(Int64(scaled), negative: value < 0)
    }

    public static func format(_ value: Decimal) -> String {
        guard !value.isNaN else { return "" }
        let halalas = NSDecimalNumber(decimal: rounded(abs(value) * 100, scale: 0)).int64Value
        return formatHalalas(halalas, negative: value < 0)
    }

    public static func amountParameter(_ amount: Decimal) -> String? {
        guard !amount.isNaN, amount > 0, amount <= maxAmount, rounded(amount, scale: 2) == amount else { return nil }
        let halalas = NSDecimalNumber(decimal: amount * 100).int64Value
        let whole = halalas / 100
        let fraction = halalas % 100
        return "\(whole)." + (fraction < 10 ? "0\(fraction)" : "\(fraction)")
    }

    static func rounded(_ value: Decimal, scale: Int) -> Decimal {
        var source = value
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, .plain)
        return result
    }

    static func formatHalalas(_ halalas: Int64, negative: Bool) -> String {
        let whole = halalas / 100
        let fraction = halalas % 100
        let digits = Array(String(whole))
        var grouped = ""
        for (offset, digit) in digits.enumerated() {
            let remaining = digits.count - offset
            if offset > 0 && remaining % 3 == 0 { grouped.append(",") }
            grouped.append(digit)
        }
        var text = grouped
        if fraction != 0 {
            text += "." + (fraction < 10 ? "0\(fraction)" : "\(fraction)")
        }
        return negative && halalas != 0 ? "-" + text : text
    }
}
