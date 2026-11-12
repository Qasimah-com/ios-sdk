import Foundation
import Testing
@testable import QasimhaCheckout

private func p(_ x: Double, _ y: Double) -> SVGPath.Point { SVGPath.Point(x: x, y: y) }

@Suite struct SVGPathTests {
    @Test func riyalPathsParseInsideTheViewBox() throws {
        for d in RiyalSymbol.paths {
            let commands = try #require(SVGPath.parse(d))
            let bounds = try #require(SVGPath.bounds(of: commands))
            #expect(!bounds.isEmpty)
            #expect(bounds.minX >= -0.5 && bounds.maxX <= RiyalSymbol.viewBoxWidth + 0.5)
            #expect(bounds.minY >= -0.5 && bounds.maxY <= RiyalSymbol.viewBoxHeight + 0.5)
            #expect(commands.last == .close)
        }
    }

    @Test func riyalSymbolCommandsAreAvailable() throws {
        let shapes = try #require(RiyalSymbol.commands)
        #expect(shapes.count == 2)
        let union = try #require(SVGPath.bounds(of: shapes.flatMap { $0 }))
        #expect(union.width > 1000 && union.height > 1200)
    }

    @Test func relativeCommandsResolveToAbsolutePoints() {
        #expect(SVGPath.parse("M10,10 l5,0 v5 h-5 z") == [.move(p(10, 10)), .line(p(15, 10)), .line(p(15, 15)), .line(p(10, 15)), .close])
        #expect(SVGPath.parse("M10,10 L20,20 H5 V0") == [.move(p(10, 10)), .line(p(20, 20)), .line(p(5, 20)), .line(p(5, 0))])
    }

    @Test func implicitLineAfterMove() {
        #expect(SVGPath.parse("M0,0 10,10 20,0") == [.move(p(0, 0)), .line(p(10, 10)), .line(p(20, 0))])
        #expect(SVGPath.parse("m5,5 1,1") == [.move(p(5, 5)), .line(p(6, 6))])
    }

    @Test func compactNumberSyntax() {
        #expect(SVGPath.parse("M0,0c1-1,2-2,3-3") == [.move(p(0, 0)), .curve(control1: p(1, -1), control2: p(2, -2), end: p(3, -3))])
        #expect(SVGPath.parse("M.5-.5") == [.move(p(0.5, -0.5))])
        #expect(SVGPath.parse("M1e1 2E-1") == [.move(p(10, 0.2))])
        #expect(SVGPath.parse("M1.5.5") == [.move(p(1.5, 0.5))])
    }

    @Test func relativeCurveUsesStartPointOfCommand() {
        #expect(SVGPath.parse("M10,10 c1,1 2,2 3,3 c1,1 2,2 3,3") == [
            .move(p(10, 10)),
            .curve(control1: p(11, 11), control2: p(12, 12), end: p(13, 13)),
            .curve(control1: p(14, 14), control2: p(15, 15), end: p(16, 16)),
        ])
    }

    @Test func closeReturnsToSubpathStart() {
        #expect(SVGPath.parse("M1,1 l2,0 z l0,3") == [.move(p(1, 1)), .line(p(3, 1)), .close, .line(p(1, 4))])
        #expect(SVGPath.parse("M1,1 l2,0 z m0,3") == [.move(p(1, 1)), .line(p(3, 1)), .close, .move(p(1, 4))])
        #expect(SVGPath.parse("M1,1 l2,0 z 5,5") == nil)
    }

    @Test(arguments: ["M0,0 A5,5 0 0 1 10,10", "M0,0 Q1,1 2,2", "M0,0 S1,1 2,2", "M0,0 T1,1"])
    func unsupportedCommandsFail(d: String) {
        #expect(SVGPath.parse(d) == nil)
    }

    @Test(arguments: ["", "hello", "M", "M1", "M1,1 L", "1,1", "M1,1 l2", "M1,1 c1,1", "M1,1 x", "M1,1 #"])
    func malformedInputFails(d: String) {
        #expect(SVGPath.parse(d) == nil)
    }

    @Test func boundsCoverControlPoints() throws {
        let commands = try #require(SVGPath.parse("M0,0 C50,-50 100,150 10,10"))
        let bounds = try #require(SVGPath.bounds(of: commands))
        #expect(bounds == SVGPath.Bounds(minX: 0, minY: -50, maxX: 100, maxY: 150))
        #expect(SVGPath.bounds(of: []) == nil)
    }
}
