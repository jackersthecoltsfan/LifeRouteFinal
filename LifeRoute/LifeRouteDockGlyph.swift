import SwiftUI

/// One 24-point drawing grid keeps the five root glyphs optically related.
/// Route nodes belong to the artwork; selection never changes its silhouette.
struct LifeRouteDockGlyph: Shape {
    let section: AppSection

    func path(in rect: CGRect) -> Path {
        var path = Path()

        switch section {
        case .today:
            // A paper-plane route marker, matching the reference dock.
            path.move(to: CGPoint(x: 13.5, y: 2.5))
            path.addLine(to: CGPoint(x: 20.5, y: 17.5))
            path.addLine(to: CGPoint(x: 13.5, y: 13.7))
            path.addLine(to: CGPoint(x: 6, y: 17.5))
            path.closeSubpath()
            path.move(to: CGPoint(x: 13.5, y: 13.7))
            path.addLine(to: CGPoint(x: 13.5, y: 18.5))
            path.addQuadCurve(to: CGPoint(x: 10.5, y: 21), control: CGPoint(x: 13.5, y: 21))
            path.addLine(to: CGPoint(x: 6, y: 21))
            node(in: &path, x: 4.5, y: 21)

        case .schedule:
            // A calendar with six small date windows.
            path.addRoundedRect(in: CGRect(x: 3, y: 5, width: 18, height: 16), cornerSize: CGSize(width: 2.5, height: 2.5))
            line(in: &path, from: CGPoint(x: 7, y: 2.5), to: CGPoint(x: 7, y: 7))
            line(in: &path, from: CGPoint(x: 17, y: 2.5), to: CGPoint(x: 17, y: 7))
            line(in: &path, from: CGPoint(x: 3, y: 9.5), to: CGPoint(x: 21, y: 9.5))
            for row in 0..<2 {
                for column in 0..<3 {
                    path.addRoundedRect(
                        in: CGRect(
                            x: 6.1 + CGFloat(column) * 5.1,
                            y: 12.4 + CGFloat(row) * 4.3,
                            width: 2.6,
                            height: 2.4
                        ),
                        cornerSize: CGSize(width: 0.8, height: 0.8)
                    )
                }
            }

        case .tools:
            // Crossed wrench and screwdriver from the reference instrument set.
            path.move(to: CGPoint(x: 4.2, y: 4.2))
            path.addLine(to: CGPoint(x: 19.8, y: 19.8))
            path.addLine(to: CGPoint(x: 18.1, y: 21.1))
            path.addLine(to: CGPoint(x: 2.9, y: 6.1))
            path.addLine(to: CGPoint(x: 4.2, y: 4.2))
            path.closeSubpath()
            path.addEllipse(in: CGRect(x: 16.9, y: 16.9, width: 4.2, height: 4.2))

            path.move(to: CGPoint(x: 19.8, y: 4.2))
            path.addLine(to: CGPoint(x: 4.2, y: 19.8))
            path.addLine(to: CGPoint(x: 2.9, y: 18.1))
            path.addLine(to: CGPoint(x: 18.1, y: 2.9))
            path.addLine(to: CGPoint(x: 19.8, y: 4.2))
            path.closeSubpath()
            path.move(to: CGPoint(x: 4.3, y: 2.8))
            path.addLine(to: CGPoint(x: 7.2, y: 5.7))
            path.addLine(to: CGPoint(x: 5.7, y: 7.2))
            path.addLine(to: CGPoint(x: 2.8, y: 4.3))
            path.closeSubpath()

        case .resources:
            // An open reference book with a clean center fold.
            path.move(to: CGPoint(x: 12, y: 5.6))
            path.addQuadCurve(to: CGPoint(x: 3, y: 4.2), control: CGPoint(x: 7.5, y: 2.8))
            path.addLine(to: CGPoint(x: 3, y: 18.5))
            path.addQuadCurve(to: CGPoint(x: 12, y: 20.4), control: CGPoint(x: 7.5, y: 17.5))
            path.addQuadCurve(to: CGPoint(x: 21, y: 18.5), control: CGPoint(x: 16.5, y: 17.5))
            path.addLine(to: CGPoint(x: 21, y: 4.2))
            path.addQuadCurve(to: CGPoint(x: 12, y: 5.6), control: CGPoint(x: 16.5, y: 2.8))
            path.closeSubpath()
            line(in: &path, from: CGPoint(x: 12, y: 5.6), to: CGPoint(x: 12, y: 20.4))

        case .setup:
            // An eight-tooth settings gear with a crisp center bore.
            let center = CGPoint(x: 12, y: 12)
            let steps = 16
            for index in 0..<steps {
                let angle = (CGFloat(index) / CGFloat(steps)) * (.pi * 2) - (.pi / 2)
                let radius: CGFloat = index.isMultiple(of: 2) ? 10.5 : 8.4
                let point = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
            path.addEllipse(in: CGRect(x: 8.5, y: 8.5, width: 7, height: 7))
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
