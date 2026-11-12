#if canImport(UIKit)
import UIKit

enum RiyalSymbolImage {
    static let aspectRatio = CGFloat(RiyalSymbol.viewBoxWidth / RiyalSymbol.viewBoxHeight)

    static func path(height: CGFloat) -> UIBezierPath? {
        guard height > 0, let shapes = RiyalSymbol.commands else { return nil }
        let path = UIBezierPath()
        for commands in shapes {
            for command in commands {
                switch command {
                case .move(let point):
                    path.move(to: CGPoint(x: point.x, y: point.y))
                case .line(let point):
                    path.addLine(to: CGPoint(x: point.x, y: point.y))
                case .curve(let control1, let control2, let end):
                    path.addCurve(to: CGPoint(x: end.x, y: end.y),
                                  controlPoint1: CGPoint(x: control1.x, y: control1.y),
                                  controlPoint2: CGPoint(x: control2.x, y: control2.y))
                case .close:
                    path.close()
                }
            }
        }
        let scale = height / CGFloat(RiyalSymbol.viewBoxHeight)
        path.apply(CGAffineTransform(scaleX: scale, y: scale))
        return path
    }

    static func image(height: CGFloat, color: UIColor) -> UIImage? {
        guard let path = path(height: height) else { return nil }
        let size = CGSize(width: ceil(height * aspectRatio), height: ceil(height))
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            color.setFill()
            path.fill()
        }
    }

    static func attachment(for font: UIFont, color: UIColor) -> NSTextAttachment? {
        guard let image = image(height: font.capHeight, color: color) else { return nil }
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        return attachment
    }
}
#endif
