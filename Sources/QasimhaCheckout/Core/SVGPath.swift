import Foundation

public enum SVGPath {
    public struct Point: Equatable, Sendable {
        public var x: Double
        public var y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    public enum Command: Equatable, Sendable {
        case move(Point)
        case line(Point)
        case curve(control1: Point, control2: Point, end: Point)
        case close
    }

    public struct Bounds: Equatable, Sendable {
        public var minX: Double
        public var minY: Double
        public var maxX: Double
        public var maxY: Double

        public var width: Double { maxX - minX }
        public var height: Double { maxY - minY }
        public var isEmpty: Bool { width <= 0 || height <= 0 }
    }

    private enum Token {
        case command(Character)
        case number(Double)
    }

    public static func parse(_ d: String) -> [Command]? {
        guard let tokens = tokenize(d), !tokens.isEmpty else { return nil }
        var commands: [Command] = []
        var current = Point(x: 0, y: 0)
        var start = current
        var pending: Character?
        var index = 0

        func take(_ count: Int) -> [Double]? {
            guard index + count <= tokens.count else { return nil }
            var values: [Double] = []
            for offset in 0..<count {
                guard case .number(let value) = tokens[index + offset] else { return nil }
                values.append(value)
            }
            index += count
            return values
        }

        while index < tokens.count {
            if case .command(let letter) = tokens[index] {
                index += 1
                if letter == "Z" || letter == "z" {
                    commands.append(.close)
                    current = start
                    pending = nil
                    continue
                }
                pending = letter
            }
            guard let letter = pending else { return nil }
            let relative = letter.isLowercase
            switch letter {
            case "M", "m":
                guard let v = take(2) else { return nil }
                let point = relative ? Point(x: current.x + v[0], y: current.y + v[1]) : Point(x: v[0], y: v[1])
                commands.append(.move(point))
                current = point
                start = point
                pending = relative ? "l" : "L"
            case "L", "l":
                guard let v = take(2) else { return nil }
                let point = relative ? Point(x: current.x + v[0], y: current.y + v[1]) : Point(x: v[0], y: v[1])
                commands.append(.line(point))
                current = point
            case "H", "h":
                guard let v = take(1) else { return nil }
                let point = Point(x: relative ? current.x + v[0] : v[0], y: current.y)
                commands.append(.line(point))
                current = point
            case "V", "v":
                guard let v = take(1) else { return nil }
                let point = Point(x: current.x, y: relative ? current.y + v[0] : v[0])
                commands.append(.line(point))
                current = point
            case "C", "c":
                guard let v = take(6) else { return nil }
                let dx = relative ? current.x : 0
                let dy = relative ? current.y : 0
                let control1 = Point(x: dx + v[0], y: dy + v[1])
                let control2 = Point(x: dx + v[2], y: dy + v[3])
                let end = Point(x: dx + v[4], y: dy + v[5])
                commands.append(.curve(control1: control1, control2: control2, end: end))
                current = end
            default:
                return nil
            }
        }
        return commands.isEmpty ? nil : commands
    }

    public static func bounds(of commands: [Command]) -> Bounds? {
        var points: [Point] = []
        for command in commands {
            switch command {
            case .move(let point), .line(let point):
                points.append(point)
            case .curve(let control1, let control2, let end):
                points.append(contentsOf: [control1, control2, end])
            case .close:
                break
            }
        }
        guard let first = points.first else { return nil }
        var bounds = Bounds(minX: first.x, minY: first.y, maxX: first.x, maxY: first.y)
        for point in points {
            bounds.minX = min(bounds.minX, point.x)
            bounds.minY = min(bounds.minY, point.y)
            bounds.maxX = max(bounds.maxX, point.x)
            bounds.maxY = max(bounds.maxY, point.y)
        }
        return bounds
    }

    private static func isDigit(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value >= 48 && scalar.value <= 57
    }

    private static func isLetter(_ scalar: Unicode.Scalar) -> Bool {
        (scalar.value >= 65 && scalar.value <= 90) || (scalar.value >= 97 && scalar.value <= 122)
    }

    private static func tokenize(_ d: String) -> [Token]? {
        let scalars = Array(d.unicodeScalars)
        var tokens: [Token] = []
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            if scalar == " " || scalar == "," || scalar == "\n" || scalar == "\t" || scalar == "\r" {
                index += 1
                continue
            }
            if isLetter(scalar) {
                tokens.append(.command(Character(scalar)))
                index += 1
                continue
            }
            guard scalar == "-" || scalar == "+" || scalar == "." || isDigit(scalar) else { return nil }
            var text = ""
            var cursor = index
            if scalars[cursor] == "-" || scalars[cursor] == "+" {
                text.unicodeScalars.append(scalars[cursor])
                cursor += 1
            }
            var sawDigit = false
            while cursor < scalars.count, isDigit(scalars[cursor]) {
                text.unicodeScalars.append(scalars[cursor])
                cursor += 1
                sawDigit = true
            }
            if cursor < scalars.count, scalars[cursor] == "." {
                text.append(".")
                cursor += 1
                while cursor < scalars.count, isDigit(scalars[cursor]) {
                    text.unicodeScalars.append(scalars[cursor])
                    cursor += 1
                    sawDigit = true
                }
            }
            guard sawDigit else { return nil }
            if cursor < scalars.count, scalars[cursor] == "e" || scalars[cursor] == "E" {
                var exponentCursor = cursor + 1
                var exponent = "e"
                if exponentCursor < scalars.count, scalars[exponentCursor] == "-" || scalars[exponentCursor] == "+" {
                    exponent.unicodeScalars.append(scalars[exponentCursor])
                    exponentCursor += 1
                }
                var exponentDigits = false
                while exponentCursor < scalars.count, isDigit(scalars[exponentCursor]) {
                    exponent.unicodeScalars.append(scalars[exponentCursor])
                    exponentCursor += 1
                    exponentDigits = true
                }
                if exponentDigits {
                    text += exponent
                    cursor = exponentCursor
                }
            }
            guard let value = Double(text), value.isFinite else { return nil }
            tokens.append(.number(value))
            index = cursor
        }
        return tokens
    }
}
