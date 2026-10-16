import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - QR codes

enum QR {
    private static let context = CIContext()

    static func image(_ text: String) -> UIImage? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(text.utf8)
        f.correctionLevel = "M"
        guard let out = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cg = context.createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// Reads a QR code out of a still image (used for "paste a QR" in the Simulator).
    static func decode(_ image: UIImage) -> String? {
        guard let ci = CIImage(image: image),
              let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: context,
                                        options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]) else { return nil }
        return detector.features(in: ci).compactMap { ($0 as? CIQRCodeFeature)?.messageString }.first
    }
}

struct QRView: View {
    let text: String
    var body: some View {
        if let img = QR.image(text) {
            Image(uiImage: img).interpolation(.none).resizable().scaledToFit()
        } else {
            Color.clear
        }
    }
}

// MARK: - Confetti

/// Book-coloured confetti burst. Purely time-driven so it never blocks touches.
struct Confetti: View {
    var origin: UnitPoint = .init(x: 0.5, y: 0.45)
    var count = 140
    @State private var start = Date()
    @State private var bits: [Bit] = []

    struct Bit {
        let vx, vy, spin, size, wobble: Double
        let color: Color
        let isBook: Bool
    }

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSince(start)
                guard t < 4.5 else { return }
                let o = CGPoint(x: size.width * origin.x, y: size.height * origin.y)
                for b in bits {
                    let x = o.x + b.vx * t + sin(t * 6 + b.wobble) * 10
                    let y = o.y + b.vy * t + 0.5 * 1300 * t * t
                    guard y < size.height + 40 else { continue }
                    var c = ctx
                    c.opacity = max(0, min(1, 4.2 - t))
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(b.spin * t))
                    let r = b.isBook ? CGRect(x: -b.size * 0.4, y: -b.size * 0.6, width: b.size * 0.8, height: b.size * 1.2)
                                     : CGRect(x: -b.size / 2, y: -b.size / 4, width: b.size, height: b.size / 2)
                    c.fill(Path(roundedRect: r, cornerRadius: b.isBook ? 2 : 1), with: .color(b.color))
                    if b.isBook {
                        c.fill(Path(CGRect(x: r.minX, y: r.minY, width: 2.5, height: r.height)), with: .color(.black.opacity(0.18)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            start = Date()
            let palette: [Color] = [K.yellow, K.blue, .white, K.t1, Color(hex: 0x1F7A6B), Color(hex: 0xE8B4BC), Color(hex: 0xC2402A)]
            bits = (0..<count).map { _ in
                let angle = Double.random(in: -Double.pi * 0.95 ... -Double.pi * 0.05)
                let speed = Double.random(in: 500...1300)
                return Bit(vx: cos(angle) * speed, vy: sin(angle) * speed, spin: .random(in: -9...9),
                           size: .random(in: 10...20), wobble: .random(in: 0...6),
                           color: palette.randomElement()!, isBook: Double.random(in: 0...1) < 0.25)
            }
        }
    }
}

// MARK: - Countdown ring

struct CountdownRing: View {
    let start: Date
    let total: TimeInterval
    var size: CGFloat = 64
    var color: Color = K.ink
    var track: Color = K.line

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
            ring(left: max(0, total - tl.date.timeIntervalSince(start)))
        }
    }

    private func ring(left: TimeInterval) -> some View {
            ZStack {
                Circle().stroke(track, lineWidth: size * 0.09)
                Circle().trim(from: 0, to: left / total)
                    .stroke(color, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(left.rounded(.up)))")
                    .font(.system(size: size * 0.34, weight: .bold).monospacedDigit())
                    .foregroundStyle(color)
                    .contentTransition(.numericText(countsDown: true))
            }
            .frame(width: size, height: size)
    }
}

// MARK: - Journey

/// "Next stop" strip with a little train sliding between stations.
struct JourneyBar: View {
    @Environment(KioskStore.self) private var store
    var dark = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { tl in
            strip(p: min(1, tl.date.timeIntervalSince(store.legStart) / store.legLength))
        }
    }

    private func strip(p: Double) -> some View {
        let mins = max(1, Int(((1 - p) * 3).rounded(.up)))
        let soft: Color = dark ? .white.opacity(0.6) : K.muted
        let strong: Color = dark ? .white : K.ink
        return HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(p > 0.92 ? "Arriving at" : "Next stop")
                        .font(.k(14, .bold))
                        .foregroundStyle(soft)
                    Text(store.nextStation)
                        .font(.k(24, .bold))
                        .foregroundStyle(strong)
                        .id(store.nextStation).transition(.push(from: .bottom))
                        .animation(.spring, value: store.nextStation)
                }
                .frame(minWidth: 170, alignment: .leading)

                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .leading) {
                        Capsule().fill(dark ? Color.white.opacity(0.15) : K.line).frame(height: 6)
                        Capsule().fill(K.yellow).frame(width: max(6, w * p), height: 6)
                        Circle().fill(K.yellow).frame(width: 14, height: 14)
                        Circle().stroke(K.yellow, lineWidth: 4).frame(width: 14, height: 14)
                            .background(Circle().fill(dark ? K.ink : Color.white))
                            .offset(x: w - 14)
                        Image(systemName: "tram.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(K.ink)
                            .frame(width: 34, height: 34)
                            .background(K.yellow, in: Circle())
                            .shadow(color: K.yellowDeep.opacity(0.5), radius: 6)
                            .offset(x: max(0, min(w - 34, w * p - 17)))
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(height: 40)

                Text(p > 0.92 ? "Now" : "\(mins) min")
                    .font(.k(16, .bold).monospacedDigit())
                    .foregroundStyle(soft)
                    .frame(width: 64, alignment: .trailing)
            }
    }
}

// MARK: - Top bar

struct TopBar: View {
    @Environment(KioskStore.self) private var store
    var showHome = true

    var body: some View {
        HStack(spacing: 22) {
            if showHome {
                Button { store.go(.home) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left").font(.system(size: 20, weight: .bold))
                        Text("Home").font(.k(20, .bold))
                    }
                    .foregroundStyle(K.blue)
                    .padding(.horizontal, 18).frame(height: 56)
                    .background(.white, in: Capsule())
                }
                .buttonStyle(PressStyle())
            } else {
                HStack(spacing: 14) {
                    LogoMark(size: 52)
                        .onLongPressGesture(minimumDuration: 2) { store.go(.staff) }
                        .accessibilityLabel("Between Stops")
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Between Stops").font(.serif(26))
                        Text("Library · Car \(store.carNumber)").font(.k(15, .bold)).foregroundStyle(K.muted)
                    }
                }
            }

            HStack(spacing: 14) {
                LinePill(size: 46)
                JourneyBar()
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            Button {
                withAnimation(.spring) { store.textScale = store.textScale == 1 ? 1.18 : 1 }
                store.showToast(store.textScale > 1 ? "Larger text on" : "Larger text off")
            } label: {
                Text("Aa")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(store.textScale > 1 ? .white : K.ink)
                    .frame(width: 56, height: 56)
                    .background(store.textScale > 1 ? K.ink : .white, in: Circle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Larger text")

            TimelineView(.everyMinute) { tl in
                Text(tl.date, format: .dateTime.hour().minute())
                    .font(.k(26, .bold).monospacedDigit())
                    .foregroundStyle(K.ink)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
    }
}

// MARK: - Section header

struct ScreenTitle: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.k(40, .bold)).foregroundStyle(K.ink)
            if let subtitle { Text(subtitle).font(.k(19)).foregroundStyle(K.muted) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Number pad

/// Big kiosk keypad used for codes and page numbers.
struct NumberPad: View {
    @Binding var text: String
    var maxLength: Int
    var dark = false
    var keyHeight: CGFloat = 86

    var body: some View {
        let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "clear", "0", "del"]
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
            ForEach(keys, id: \.self) { k in
                Button { press(k) } label: {
                    Group {
                        switch k {
                        case "del": Image(systemName: "delete.left.fill").font(.system(size: 28))
                        case "clear": Text("Clear").font(.k(20, .bold))
                        default: Text(k).font(.system(size: 36, weight: .bold))
                        }
                    }
                    .foregroundStyle(dark ? .white : K.ink)
                    .frame(maxWidth: .infinity).frame(height: keyHeight)
                    .background(keyColor(k), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(PressStyle(scale: 0.93))
            }
        }
    }

    private func keyColor(_ k: String) -> Color {
        if dark { return .white.opacity(k.count == 1 ? 0.1 : 0.05) }
        return k.count == 1 ? .white : K.grey
    }

    private func press(_ k: String) {
        switch k {
        case "del": if !text.isEmpty { text.removeLast() }
        case "clear": text = ""
        default:
            guard text.count < maxLength else { return }
            text += k
        }
    }
}

// MARK: - Stars

/// Read-only star rating, e.g. 4.5 ★★★★½.
struct Stars: View {
    let value: Double
    var size: CGFloat = 16
    var color: Color = K.yellowDeep

    var body: some View {
        HStack(spacing: size * 0.12) {
            ForEach(1...5, id: \.self) { i in
                let d = Double(i)
                Image(systemName: value >= d ? "star.fill" : (value >= d - 0.5 ? "star.leadinghalf.filled" : "star"))
            }
        }
        .font(.system(size: size, weight: .semibold))
        .foregroundStyle(color)
        .accessibilityLabel(String(format: "%.1f out of 5 stars", value))
    }
}

// MARK: - Step indicator

/// "Scan your pass → Door opens → Take your book". Shows readers that everything from here happens at the kiosk.
struct StepsBar: View {
    let labels: [String]
    let current: Int
    var dark = true

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(labels.enumerated()), id: \.offset) { i, label in
                if i > 0 {
                    Capsule().fill(i <= current ? Color(hex: 0x3DDC97) : line).frame(width: 56, height: 2)
                }
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(i < current ? Color(hex: 0x3DDC97) : .clear)
                        Circle().stroke(i < current ? Color(hex: 0x3DDC97) : i == current ? accent : line, lineWidth: 2)
                        if i < current {
                            Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(K.ink)
                        } else {
                            Text("\(i + 1)").font(.k(16, .bold)).foregroundStyle(i == current ? accent : faded)
                        }
                    }
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(i == current ? accent.opacity(0.18) : .clear).padding(-5))
                    Text(label).font(.k(17, .bold))
                        .foregroundStyle(i == current ? strong : i < current ? strong.opacity(0.85) : faded)
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: current)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(min(current + 1, labels.count)) of \(labels.count): \(labels[min(current, labels.count - 1)])")
    }

    private var accent: Color { dark ? K.yellow : K.ink }
    private var strong: Color { dark ? .white : K.ink }
    private var faded: Color { dark ? .white.opacity(0.45) : K.muted }
    private var line: Color { dark ? .white.opacity(0.2) : K.line }
}
