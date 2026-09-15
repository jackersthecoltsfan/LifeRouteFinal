import SwiftUI

/// One 24-point drawing grid keeps the five root glyphs optically related.
/// Route nodes belong to the artwork; selection never changes its silhouette.
struct LifeRouteDockGlyph: Shape {
    let section: AppSection

    func path(in rect: CGRect) -> Path {
        var path = Path()

        switch section {
        case .today:
            // A direction needle with a short route returning to its origin.
            path.move(to: CGPoint(x: 13, y: 2.5))
            path.addLine(to: CGPoint(x: 19.5, y: 17))
            path.addLine(to: CGPoint(x: 13, y: 13.4))
            path.addLine(to: CGPoint(x: 6.5, y: 17))
            path.closeSubpath()
            path.move(to: CGPoint(x: 13, y: 13.4))
            path.addLine(to: CGPoint(x: 13, y: 18))
            path.addQuadCurve(to: CGPoint(x: 10.5, y: 20.5), control: CGPoint(x: 13, y: 20.5))
            path.addLine(to: CGPoint(x: 6, y: 20.5))
            node(in: &path, x: 4.5, y: 20.5)

        case .schedule:
            path.addRoundedRect(in: CGRect(x: 3, y: 5, width: 18, height: 16), cornerSize: CGSize(width: 2.5, height: 2.5))
            line(in: &path, from: CGPoint(x: 7, y: 2.5), to: CGPoint(x: 7, y: 7))
            line(in: &path, from: CGPoint(x: 17, y: 2.5), to: CGPoint(x: 17, y: 7))
            line(in: &path, from: CGPoint(x: 3, y: 9.5), to: CGPoint(x: 21, y: 9.5))
            // Two dates joined by the same small, rounded route as Today.
            node(in: &path, x: 7, y: 14)
            path.move(to: CGPoint(x: 8.5, y: 14))
            path.addLine(to: CGPoint(x: 11, y: 14))
            path.addQuadCurve(to: CGPoint(x: 12.5, y: 15.5), control: CGPoint(x: 12.5, y: 14))
            path.addQuadCurve(to: CGPoint(x: 14, y: 17), control: CGPoint(x: 12.5, y: 17))
            path.addLine(to: CGPoint(x: 15.5, y: 17))
            node(in: &path, x: 17, y: 17)

        case .tools:
            // A single open-jaw wrench keeps the small silhouette readable.
            path.move(to: CGPoint(x: 14, y: 3.3))
            path.addCurve(to: CGPoint(x: 11.7, y: 10), control1: CGPoint(x: 10.8, y: 4.1), control2: CGPoint(x: 10, y: 7.4))
            path.addLine(to: CGPoint(x: 3.01, y: 16.21))
            path.addArc(center: CGPoint(x: 5.2, y: 18.4), radius: 3.1,
                        startAngle: .degrees(-135), endAngle: .degrees(45), clockwise: true)
            path.addLine(to: CGPoint(x: 14, y: 12.3))
            path.addCurve(to: CGPoint(x: 20.7, y: 10), control1: CGPoint(x: 16.6, y: 14), control2: CGPoint(x: 19.9, y: 13.2))
            path.addLine(to: CGPoint(x: 17, y: 10.5))
            path.addLine(to: CGPoint(x: 13.5, y: 7))
            path.closeSubpath()
            node(in: &path, x: 5.2, y: 18.4, radius: 1)

        case .resources:
            // The center fold and outer pages read as an open reference book.
            path.move(to: CGPoint(x: 12, y: 6))
            path.addQuadCurve(to: CGPoint(x: 3, y: 4.5), control: CGPoint(x: 7.5, y: 3))
            path.addLine(to: CGPoint(x: 3, y: 18.5))
            path.addQuadCurve(to: CGPoint(x: 12, y: 20), control: CGPoint(x: 7.5, y: 17))
            path.addQuadCurve(to: CGPoint(x: 21, y: 18.5), control: CGPoint(x: 16.5, y: 17))
            path.addLine(to: CGPoint(x: 21, y: 4.5))
            path.addQuadCurve(to: CGPoint(x: 12, y: 6), control: CGPoint(x: 16.5, y: 3))
            path.closeSubpath()
            line(in: &path, from: CGPoint(x: 12, y: 6), to: CGPoint(x: 12, y: 20))
            // A short bookmark route and node replaces miniature page text.
            line(in: &path, from: CGPoint(x: 16.5, y: 5), to: CGPoint(x: 16.5, y: 10.5))
            node(in: &path, x: 16.5, y: 12)

        case .setup:
            // Familiar tuning rails share the same outlined route nodes.
            line(in: &path, from: CGPoint(x: 3, y: 5), to: CGPoint(x: 7.5, y: 5))
            line(in: &path, from: CGPoint(x: 10.5, y: 5), to: CGPoint(x: 21, y: 5))
            node(in: &path, x: 9, y: 5)
            line(in: &path, from: CGPoint(x: 3, y: 12), to: CGPoint(x: 14.5, y: 12))
            line(in: &path, from: CGPoint(x: 17.5, y: 12), to: CGPoint(x: 21, y: 12))
            node(in: &path, x: 16, y: 12)
            line(in: &path, from: CGPoint(x: 3, y: 19), to: CGPoint(x: 6.5, y: 19))
            line(in: &path, from: CGPoint(x: 9.5, y: 19), to: CGPoint(x: 21, y: 19))
            node(in: &path, x: 8, y: 19)
        }

        let scale = min(rect.width, rect.height) / 24
        let origin = CGPoint(x: rect.midX - 12 * scale, y: rect.midY - 12 * scale)
        return path.applying(CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: origin.x, ty: origin.y))
    }

    private func line(in path: inout Path, from start: CGPoint, to end: CGPoint) {
        path.move(to: start)
        path.addLine(to: end)
    }

    private func node(in path: inout Path, x: CGFloat, y: CGFloat, radius: CGFloat = 1.5) {
        path.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
    }
}
