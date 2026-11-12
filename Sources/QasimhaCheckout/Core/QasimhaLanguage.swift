import Foundation

public enum QasimhaLanguage: String, Equatable, Sendable {
    case ar
    case en

    public static func resolve(_ raw: String?) -> QasimhaLanguage {
        guard let raw = raw else { return .ar }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value == "en" || value.hasPrefix("en-") || value.hasPrefix("en_") { return .en }
        return .ar
    }

    public var isRightToLeft: Bool { self == .ar }
}
