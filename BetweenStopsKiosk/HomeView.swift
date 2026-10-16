import SwiftUI

/// Main screen. Scanning is always on, so collecting a reservation takes zero taps.
struct HomeView: View {
    @Environment(KioskStore.self) private var store
    @State private var shown = false

    var body: some View {
        VStack(spacing: 0) {
            TopBar(showHome: false)

            HStack(alignment: .top, spacing: 24) {
                collectCard
                    .frame(maxWidth: .infinity)
                    .offset(x: shown ? 0 : -40)
                    .opacity(shown ? 1 : 0)

                VStack(spacing: 16) {
                    // Borrowing without a phone comes first, so walk-up readers find it straight away.
                    browseTile
                        .entrance(shown, delay: 0.05)
                    Tile(symbol: "arrow.uturn.down", tint: K.yellow, title: "Return a book",
                         subtitle: "Finished? Pop it back on the shelf") { store.go(.returnBook(nil)) }
                        .entrance(shown, delay: 0.12)
                    Tile(symbol: "questionmark", tint: K.grey, title: "How it works",
                         subtitle: "Help, larger text and staff assist") { store.go(.help) }
                        .entrance(shown, delay: 0.19)
                    Button { withAnimation(.spring) { store.showTour = true } } label: {
                        Label("New here? Take the 30 second tour", systemImage: "sparkles")
                            .font(.k(18, .bold)).foregroundStyle(K.blue)
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(K.line, style: StrokeStyle(lineWidth: 2, dash: [6, 5])))
                    }
                    .buttonStyle(PressStyle())
                    .entrance(shown, delay: 0.24)
                    todayStrip
                        .entrance(shown, delay: 0.28)
                }
                .frame(width: 420)
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 28)
        }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { shown = true } }
    }

    private var collectCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Have a pass? Scan it here").font(.k(40, .bold))
                    Text("Hold the QR code from your phone up to the camera. Everything else happens here at the kiosk.")
                        .font(.k(19)).foregroundStyle(.white.opacity(0.7))
                    HStack(spacing: 10) {
                        ForEach(Array(["Scan pass", "Door opens", "Take your book"].enumerated()), id: \.offset) { i, s in
                            if i > 0 { Text("→").foregroundStyle(.white.opacity(0.35)) }
                            HStack(spacing: 6) {
                                Text("\(i + 1)").font(.k(13, .bold)).foregroundStyle(K.ink)
                                    .frame(width: 24, height: 24).background(K.yellow, in: Circle())
                                Text(s)
                            }
                        }
                    }
                    .font(.k(16, .bold)).foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 6)
                }
                Spacer()
            }
            .foregroundStyle(.white)

            Viewfinder()
                .frame(maxHeight: .infinity)

            if !store.hasCamera || store.showDemoPasses {
                DemoScanTray()
            }

            Button { store.go(.code) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "circle.grid.3x3.fill")
                    Text("Type my 6 digit code instead")
                }
            }
            .buttonStyle(KioskButtonStyle(kind: .white, height: 64))
        }
        .padding(26)
        .frame(maxHeight: .infinity)
        .background(K.ink, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    private var browseTile: some View {
        Button { store.go(.browse) } label: {
            HStack(spacing: 18) {
                ZStack {
                    ForEach(Array(store.booksOnShelf.prefix(3).enumerated()), id: \.offset) { i, b in
                        BookCover(book: b, width: 46, showText: false)
                            .rotationEffect(.degrees(Double(i - 1) * 12), anchor: .bottom)
                            .offset(x: CGFloat(i - 1) * 12)
                    }
                }
                .frame(width: 76, height: 76)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Browse the shelf").font(.k(24, .bold)).lineLimit(1)
                    Text("\(store.availableCount) books ready to borrow now")
                        .font(.k(16)).foregroundStyle(K.muted).lineLimit(1)
                    Label("No phone or reservation needed", systemImage: "checkmark")
                        .font(.k(13, .bold)).foregroundStyle(K.green)
                        .lineLimit(1).minimumScaleFactor(0.75)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(K.greenSoft, in: Capsule())
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 20, weight: .bold)).foregroundStyle(K.line)
            }
            .foregroundStyle(K.ink)
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(PressStyle())
    }

    private var todayStrip: some View {
        HStack(spacing: 12) {
            stat("\(store.borrowedToday)", "borrowed today", dark: true)
            stat("\(store.returnedToday)", "returned today", dark: false)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private func stat(_ n: String, _ label: String, dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(n).font(.k(34, .bold).monospacedDigit())
                .contentTransition(.numericText())
                .animation(.spring, value: n)
            Text(label).font(.k(15)).opacity(0.7)
        }
        .foregroundStyle(dark ? .white : K.ink)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(dark ? K.blue : .white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct Tile: View {
    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 18) {
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(K.ink)
                    .frame(width: 76, height: 76)
                    .background(tint, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.k(24, .bold))
                    Text(subtitle).font(.k(16)).foregroundStyle(K.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 20, weight: .bold)).foregroundStyle(K.line)
            }
            .foregroundStyle(K.ink)
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(PressStyle())
    }
}

extension View {
    /// Slide-and-fade entrance used for staggered lists.
    func entrance(_ shown: Bool, delay: Double) -> some View {
        self
            .offset(x: shown ? 0 : 40)
            .opacity(shown ? 1 : 0)
            .animation(.spring(response: 0.55, dampingFraction: 0.82).delay(delay), value: shown)
    }
}
