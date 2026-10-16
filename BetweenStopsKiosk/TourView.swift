import SwiftUI

/// Optional step-by-step tour from Home or How it works, with Back, Next and Skip.
struct TourView: View {
    @Environment(KioskStore.self) private var store
    @State private var step = 0
    @State private var doorOpen = false

    private struct Step {
        let title: String
        let body: String
        let tint: Color
    }

    private let steps = [
        Step(title: "Welcome to Between Stops",
             body: "A free library that rides on the train. Borrow a book for your trip and return it on any library train when you're done.",
             tint: K.ink),
        Step(title: "Reserved a book? Scan your pass",
             body: "Hold the QR code from the Between Stops app up to the camera on the home screen. No QR? Type your 6 digit code or 4 digit quick code instead.",
             tint: Color(hex: 0xE3EAF5)),
        Step(title: "Your door opens",
             body: "A door on the shelf lights up and swings open. Take your book, and the door closes by itself. No need to go back to your phone.",
             tint: K.ink),
        Step(title: "No phone? Browse the shelf",
             body: "Tap Browse the shelf to see every book behind the glass. Anything that isn't reserved can be borrowed straight away. No account needed.",
             tint: K.greenSoft),
        Step(title: "Returning a book",
             body: "Tap Return a book and scan the barcode on the back cover. Pop it in the open door, then save your page or leave a review.",
             tint: K.held),
    ]

    var body: some View {
        ZStack {
            K.ink.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                HStack {
                    Spacer()
                    Button("Skip tour") { close() }
                        .font(.k(18, .bold)).foregroundStyle(K.muted)
                        .buttonStyle(PressStyle())
                }

                Group {
                    art
                        .frame(maxWidth: .infinity).frame(height: 250)
                        .background(steps[step].tint, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    Text("Step \(step + 1) of \(steps.count)").font(.k(16, .bold)).foregroundStyle(K.muted)
                    Text(steps[step].title).font(.k(32, .bold)).foregroundStyle(K.ink)
                    Text(steps[step].body).font(.k(19)).foregroundStyle(K.muted)
                        .multilineTextAlignment(.center).lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 560)
                }
                .id(step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))

                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Capsule().fill(i == step ? K.ink : K.line).frame(width: i == step ? 30 : 10, height: 10)
                    }
                }
                .animation(.spring, value: step)

                HStack(spacing: 14) {
                    Button { go(step - 1) } label: { Label("Back", systemImage: "chevron.left") }
                        .buttonStyle(KioskButtonStyle(kind: .ghost, height: 60))
                        .disabled(step == 0).opacity(step == 0 ? 0.4 : 1)
                    Button {
                        step == steps.count - 1 ? close() : go(step + 1)
                    } label: {
                        Label(step == steps.count - 1 ? "Got it" : "Next",
                              systemImage: step == steps.count - 1 ? "checkmark" : "chevron.right")
                    }
                    .buttonStyle(KioskButtonStyle(kind: .yellow, height: 60))
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 40).padding(.vertical, 28)
            .frame(width: 720)
            .background(K.bg, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
            .shadow(color: K.ink.opacity(0.3), radius: 40, y: 20)
        }
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder private var art: some View {
        switch step {
        case 0:
            HStack(alignment: .bottom, spacing: -14) {
                ForEach(Array(store.books.prefix(3).enumerated()), id: \.offset) { i, b in
                    BookCover(book: b, width: 110)
                        .rotationEffect(.degrees(Double(i - 1) * 10))
                        .offset(y: i == 1 ? -12 : 0)
                }
            }
        case 1:
            HStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("Your pass").font(.system(size: 12, weight: .bold))
                    QRView(text: Catalog.demoPasses[0].payload).frame(width: 90, height: 90)
                    Text("482 913").font(.system(size: 14, weight: .bold).monospacedDigit())
                }
                .foregroundStyle(K.ink)
                .padding(14)
                .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(hex: 0x1B1D22), lineWidth: 5))
                Image(systemName: "chevron.right.2").font(.system(size: 34, weight: .bold)).foregroundStyle(K.ink.opacity(0.5))
                Image(systemName: "qrcode.viewfinder").font(.system(size: 40, weight: .semibold)).foregroundStyle(K.yellow)
                    .frame(width: 84, height: 84).background(K.ink, in: Circle())
            }
        case 2:
            HStack(spacing: 12) {
                ForEach(["redfern", "tides", "signal"], id: \.self) { id in
                    if let s = store.slots.first(where: { $0.bookID == id }) ?? store.slots.first {
                        LockerDoor(slot: Slot(id: s.id, bookID: id, hold: nil), book: store.book(id),
                                   open: id == "tides" && doorOpen, highlight: id == "tides", w: 96)
                    }
                }
            }
            .task {
                doorOpen = false
                try? await Task.sleep(for: .seconds(0.7))
                doorOpen = true
            }
        case 3:
            ZStack(alignment: .bottom) {
                HStack(spacing: 16) {
                    ForEach(store.booksOnShelf.filter { !store.isHeld($0.id) }.prefix(3)) { b in
                        BookCover(book: b, width: 100)
                    }
                }
                .padding(.bottom, 40)
                Label("Borrow now", systemImage: "lock.open.fill")
                    .font(.k(18, .bold)).foregroundStyle(K.ink)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(K.yellow, in: Capsule())
                    .padding(.bottom, 14)
            }
        default:
            HStack(spacing: 20) {
                Image(systemName: "arrow.uturn.down").font(.system(size: 40, weight: .bold)).foregroundStyle(K.ink)
                    .frame(width: 96, height: 96).background(K.yellow, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                Image(systemName: "chevron.right.2").font(.system(size: 30, weight: .bold)).foregroundStyle(K.ink.opacity(0.5))
                if let salt = store.book("salt") { BookCover(book: salt, width: 100) }
                Image(systemName: "chevron.right.2").font(.system(size: 30, weight: .bold)).foregroundStyle(K.ink.opacity(0.5))
                VStack(spacing: 12) {
                    Image(systemName: "bookmark.fill")
                    Image(systemName: "star.fill")
                }
                .font(.system(size: 36)).foregroundStyle(K.ink)
            }
        }
    }

    private func go(_ i: Int) {
        store.touch()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { step = max(0, min(steps.count - 1, i)) }
    }

    private func close() {
        withAnimation(.spring) { store.showTour = false }
    }
}
