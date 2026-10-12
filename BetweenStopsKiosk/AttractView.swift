import SwiftUI

/// The screensaver. Books drift up, a train glides along the bottom, and any touch starts.
struct AttractView: View {
    @Environment(KioskStore.self) private var store
    @State private var factIndex = 0
    @State private var breathe = false
    @State private var appeared = false

    private var facts: [String] {
        [
            "\(store.borrowedToday) books borrowed on the T1 today",
            "\(store.kmThisWeek.formatted()) km travelled by our books this week",
            "Most travelled book: The Long Way to Redfern, 412 km",
            "\(store.availableCount) books are waiting on this shelf right now",
            "Finished a book? Return it to any library train",
        ]
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [K.ink, Color(hex: 0x0F141F)], startPoint: .top, endPoint: .bottom)

                FloatingBooks(size: geo.size)
                    .opacity(0.9)

                // soft vignette so the words stay readable
                LinearGradient(colors: [Color(hex: 0x0F141F).opacity(0.95), Color(hex: 0x0F141F).opacity(0.55), .clear],
                               startPoint: .leading, endPoint: .trailing)

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        LogoMark(size: 72)
                        Spacer()
                        HStack(spacing: 14) {
                            LinePill(size: 46)
                            JourneyBar(dark: true).frame(width: 460)
                        }
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }

                    Spacer()

                    Text("Between Stops")
                        .font(.serif(104))
                        .foregroundStyle(.white)
                        .offset(y: appeared ? 0 : 30)
                        .opacity(appeared ? 1 : 0)
                    Text("The library that rides with you.")
                        .font(.k(30))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 6)
                        .offset(y: appeared ? 0 : 30)
                        .opacity(appeared ? 1 : 0)

                    HStack(spacing: 12) {
                        Image(systemName: "sparkles").foregroundStyle(K.yellow)
                        Text(facts[factIndex % facts.count])
                            .id(factIndex)
                            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                                    removal: .move(edge: .top).combined(with: .opacity)))
                    }
                    .font(.k(22, .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(height: 34, alignment: .leading)
                    .clipped()
                    .padding(.top, 34)

                    HStack(spacing: 18) {
                        HStack(spacing: 14) {
                            Image(systemName: "hand.tap.fill")
                            Text("Touch to start")
                        }
                        .font(.k(28, .bold))
                        .foregroundStyle(K.ink)
                        .padding(.horizontal, 34).frame(height: 84)
                        .background(K.yellow, in: Capsule())
                        .shadow(color: K.yellow.opacity(breathe ? 0.6 : 0.2), radius: breathe ? 30 : 10)
                        .scaleEffect(breathe ? 1.04 : 1)

                        Text("Reserved a book in the app?\nTouch, then scan your QR code.")
                            .font(.k(19))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    .padding(.top, 34)

                    Spacer().frame(height: 170)
                }
                .padding(.horizontal, 64)
                .padding(.top, 44)

                VStack {
                    Spacer()
                    RollingTrain(width: geo.size.width)
                        .padding(.bottom, 34)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { store.go(.home) }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { appeared = true }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { breathe = true }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.5))
                withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { factIndex += 1 }
            }
        }
    }
}

/// Covers drifting upward on the right-hand side at different depths.
struct FloatingBooks: View {
    @Environment(KioskStore.self) private var store
    let size: CGSize
    @State private var start = Date()

    private struct Floater { let x, speed, width, phase, tilt: Double; let book: Book }

    private var floaters: [Floater] {
        let books = store.books
        return (0..<11).map { i in
            let depth = Double((i * 7) % 5) / 4  // 0...1
            return Floater(x: 0.55 + Double((i * 23) % 40) / 100,
                           speed: 22 + depth * 30,
                           width: 90 + depth * 90,
                           phase: Double(i) * 173,
                           tilt: Double((i * 13) % 17) - 8,
                           book: books[i % books.count])
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
            let t = tl.date.timeIntervalSince(start)
            ZStack {
                ForEach(Array(floaters.enumerated()), id: \.offset) { _, f in
                    let travel = size.height + f.width * 2
                    let y = size.height + f.width - ((t * f.speed + f.phase).truncatingRemainder(dividingBy: travel))
                    BookCover(book: f.book, width: f.width)
                        .rotationEffect(.degrees(f.tilt + sin(t * 0.4 + f.phase) * 6))
                        .position(x: size.width * f.x + sin(t * 0.3 + f.phase) * 20, y: y)
                        .opacity(0.2 + f.width / 360)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// An 8 car Waratah-ish train rolling across the screen. Car 2, with the library, glows yellow.
struct RollingTrain: View {
    let width: CGFloat
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60)) { tl in
            let t = tl.date.timeIntervalSince(start)
            let trainW: CGFloat = 8 * 118
            let loop = width + trainW + 200
            let x = (t * 140).truncatingRemainder(dividingBy: loop) - trainW
            ZStack(alignment: .bottomLeading) {
                // track
                Rectangle().fill(.white.opacity(0.12)).frame(height: 3).offset(y: 10)
                HStack(spacing: 6) {
                    ForEach(Array((1...8).reversed()), id: \.self) { car in
                        TrainCar(index: car, highlighted: car == 2, bob: sin(t * 9 + Double(car)) * 0.8)
                    }
                }
                .offset(x: x)
            }
            .frame(width: width, height: 90, alignment: .bottomLeading)
        }
        .allowsHitTesting(false)
    }
}

struct TrainCar: View {
    let index: Int
    let highlighted: Bool
    var bob: Double = 0

    var body: some View {
        ZStack(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: index == 8 ? 28 : 10, bottomLeadingRadius: 6,
                                   bottomTrailingRadius: 6, topTrailingRadius: index == 1 ? 28 : 10, style: .continuous)
                .fill(highlighted ? K.yellow : .white.opacity(0.14))
                .frame(width: 112, height: 52)
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 3).fill(highlighted ? K.ink.opacity(0.3) : .white.opacity(0.22))
                        .frame(width: 22, height: 14)
                }
            }
            .padding(.top, 11)
            if highlighted {
                HStack(alignment: .bottom, spacing: 3) {
                    RoundedRectangle(cornerRadius: 1.5).fill(.white).frame(width: 5, height: 16)
                    RoundedRectangle(cornerRadius: 1.5).fill(.white).frame(width: 5, height: 12)
                    RoundedRectangle(cornerRadius: 1.5).fill(.white).frame(width: 5, height: 18)
                }
                .offset(y: -24)
            }
        }
        .offset(y: bob)
    }
}
