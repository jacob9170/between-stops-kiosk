import SwiftUI

/// The same generated covers as the phone app, drawn natively.
struct BookCover: View {
    let book: Book
    var width: CGFloat = 120
    var showText = true

    var height: CGFloat { width * 146 / 100 }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            book.c1
            Canvas { ctx, size in
                ctx.scaleBy(x: size.width / 100, y: size.width / 100)
                CoverArtist.draw(book, in: &ctx)
            }
            if showText && width >= 80 {
                VStack(alignment: .leading, spacing: width * 0.04) {
                    Text(book.title)
                        .font(.system(size: width * 0.125, weight: .semibold, design: .serif))
                        .lineSpacing(-2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(book.author)
                        .font(.system(size: width * 0.07))
                        .opacity(0.85)
                }
                .foregroundStyle(book.c2)
                .padding(.horizontal, width * 0.1)
                .padding(.bottom, width * 0.11)
            }
            // spine shadow
            LinearGradient(colors: [.black.opacity(0.22), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: max(3, width * 0.05))
                .frame(maxHeight: .infinity)
        }
        .frame(width: width, height: height)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: width * 0.035, bottomLeadingRadius: width * 0.035,
                                          bottomTrailingRadius: width * 0.075, topTrailingRadius: width * 0.075,
                                          style: .continuous))
        .shadow(color: K.ink.opacity(0.22), radius: width * 0.08, y: width * 0.06)
        .accessibilityElement()
        .accessibilityLabel("\(book.title) by \(book.author)")
    }
}

enum CoverArtist {
    static func draw(_ b: Book, in ctx: inout GraphicsContext) {
        let c = b.c2
        switch b.art {
        case .sun:
            ctx.fill(Path(ellipseIn: CGRect(x: 48, y: 12, width: 44, height: 44)), with: .color(c))
            ctx.fill(Path(CGRect(x: 0, y: 62, width: 100, height: 3)), with: .color(c.opacity(0.5)))
        case .waves:
            for (i, y) in [30.0, 44, 58].enumerated() {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                for k in 0..<4 {
                    let x0 = Double(k) * 25
                    p.addQuadCurve(to: CGPoint(x: x0 + 25, y: y), control: CGPoint(x: x0 + 12.5, y: y + (k % 2 == 0 ? -8 : 8)))
                }
                ctx.stroke(p, with: .color(c.opacity([1, 0.6, 0.3][i])), lineWidth: 4)
            }
        case .stripes:
            for k in 0..<5 {
                var p = Path()
                let x = -10 + Double(k) * 20
                p.move(to: CGPoint(x: x, y: 40)); p.addLine(to: CGPoint(x: x + 50, y: -10))
                ctx.stroke(p, with: .color(c.opacity(0.9)), lineWidth: 7)
            }
        case .circle:
            ctx.stroke(Path(ellipseIn: CGRect(x: 20, y: 10, width: 60, height: 60)), with: .color(c), lineWidth: 5)
            ctx.fill(Path(ellipseIn: CGRect(x: 38, y: 28, width: 24, height: 24)), with: .color(c))
        case .dots:
            for r in 0..<5 { for k in 0..<5 {
                let center = CGPoint(x: 14 + Double(k) * 18, y: 12 + Double(r) * 14)
                ctx.fill(Path(ellipseIn: CGRect(x: center.x - 3.5, y: center.y - 3.5, width: 7, height: 7)),
                         with: .color(c.opacity(r == 2 && k == 2 ? 1 : 0.45)))
            } }
        case .bird:
            var p = Path()
            p.move(to: CGPoint(x: 20, y: 50))
            p.addQuadCurve(to: CGPoint(x: 50, y: 40), control: CGPoint(x: 35, y: 20))
            p.addQuadCurve(to: CGPoint(x: 80, y: 26), control: CGPoint(x: 60, y: 20))
            p.addQuadCurve(to: CGPoint(x: 62, y: 46), control: CGPoint(x: 68, y: 30))
            p.addQuadCurve(to: CGPoint(x: 20, y: 50), control: CGPoint(x: 54, y: 68))
            ctx.fill(p, with: .color(c))
            ctx.fill(Path(ellipseIn: CGRect(x: 63.5, y: 25.5, width: 5, height: 5)), with: .color(b.c1))
        case .moon:
            ctx.fill(Path(ellipseIn: CGRect(x: 42, y: 12, width: 40, height: 40)), with: .color(c))
            ctx.fill(Path(ellipseIn: CGRect(x: 55, y: 9, width: 34, height: 34)), with: .color(b.c1))
            for (x, y, r) in [(24.0, 18.0, 1.6), (36, 44, 1.2), (16, 54, 1.4)] {
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(c))
            }
        case .lines:
            for i in 0..<7 {
                ctx.fill(Path(CGRect(x: 10, y: 12 + Double(i) * 8, width: 80 - Double(i % 3) * 18, height: 2.5)),
                         with: .color(c.opacity(0.7)))
            }
        }
    }
}

/// A thin book spine, used inside the locker doors.
struct Spine: View {
    let book: Book
    var height: CGFloat = 90
    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(book.c1)
            .frame(width: height * 0.2, height: height)
            .overlay(alignment: .top) {
                Rectangle().fill(book.c2.opacity(0.8)).frame(height: 3).padding(.top, height * 0.12)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(book.c2.opacity(0.8)).frame(height: 3).padding(.bottom, height * 0.12)
            }
    }
}
