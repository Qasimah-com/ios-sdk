import Foundation

public struct PromoPlan: Equatable, Sendable {
    public let instalments: Int
    public let frequency: String
    public let instalmentAmount: Double
    public let firstInstalmentAmount: Double
    public let lastInstalmentAmount: Double
    public let feesIncludingVat: Double
    public let totalPayable: Double
    public let shariaCompliant: Bool

    public init(instalments: Int, frequency: String, instalmentAmount: Double, firstInstalmentAmount: Double,
                lastInstalmentAmount: Double, feesIncludingVat: Double, totalPayable: Double, shariaCompliant: Bool) {
        self.instalments = instalments
        self.frequency = frequency
        self.instalmentAmount = instalmentAmount
        self.firstInstalmentAmount = firstInstalmentAmount
        self.lastInstalmentAmount = lastInstalmentAmount
        self.feesIncludingVat = feesIncludingVat
        self.totalPayable = totalPayable
        self.shariaCompliant = shariaCompliant
    }
}

public struct PromoPlans: Equatable, Sendable {
    public let merchantName: String
    public let minAmount: Double
    public let maxAmount: Double
    public let plans: [PromoPlan]
}

public enum PlansResponse {
    public static func parse(_ data: Data, amount: Decimal) -> PromoPlans? {
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.success == true,
              let payload = envelope.data,
              payload.currency == "SAR",
              let minAmount = money(payload.minAmount),
              let maxAmount = money(payload.maxAmount) else { return nil }
        let value = NSDecimalNumber(decimal: amount).doubleValue
        guard value.isFinite, value >= minAmount, value <= maxAmount else { return nil }
        let plans = (payload.plans ?? []).compactMap { $0.value.flatMap(plan(from:)) }
        guard !plans.isEmpty else { return nil }
        return PromoPlans(merchantName: payload.merchantName ?? "", minAmount: minAmount, maxAmount: maxAmount, plans: plans)
    }

    private static func money(_ value: Double?) -> Double? {
        guard let value = value, value.isFinite, value >= 0 else { return nil }
        return value
    }

    private static func plan(from raw: RawPlan) -> PromoPlan? {
        guard let instalments = raw.instalments, (1...60).contains(instalments),
              let amount = money(raw.instalmentAmount),
              let total = money(raw.totalPayable) else { return nil }
        let first = raw.firstInstalmentAmount == nil ? amount : money(raw.firstInstalmentAmount)
        let last = raw.lastInstalmentAmount == nil ? amount : money(raw.lastInstalmentAmount)
        let fees = raw.feesIncludingVat == nil ? 0 : money(raw.feesIncludingVat)
        guard let firstAmount = first, let lastAmount = last, let feeAmount = fees else { return nil }
        return PromoPlan(instalments: instalments,
                         frequency: raw.frequency?.lowercased() ?? "monthly",
                         instalmentAmount: amount,
                         firstInstalmentAmount: firstAmount,
                         lastInstalmentAmount: lastAmount,
                         feesIncludingVat: feeAmount,
                         totalPayable: total,
                         shariaCompliant: raw.shariaCompliant == true)
    }

    private struct Envelope: Decodable {
        let success: Bool?
        let data: Payload?
    }

    private struct Payload: Decodable {
        let merchantName: String?
        let currency: String?
        let minAmount: Double?
        let maxAmount: Double?
        let plans: [Lossy<RawPlan>]?
    }

    private struct RawPlan: Decodable {
        let instalments: Int?
        let frequency: String?
        let instalmentAmount: Double?
        let firstInstalmentAmount: Double?
        let lastInstalmentAmount: Double?
        let feesIncludingVat: Double?
        let totalPayable: Double?
        let shariaCompliant: Bool?
    }

    private struct Lossy<Value: Decodable>: Decodable {
        let value: Value?

        init(from decoder: Decoder) {
            value = try? Value(from: decoder)
        }
    }
}
