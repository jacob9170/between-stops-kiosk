import SwiftUI
import AudioToolbox

/// Checks the pass, finds the door, swings it open and flies the book out.
struct UnlockView: View {
    @Environment(KioskStore.self) private var store
    let job: CollectJob

    enum Phase { case checking, opening, open, done }
    @State private var phase: Phase = .checking
    @State private var scanSlot: String?
    @State private var doorOpen = false
    @State private var bookOut = false
    @State private var confetti = false
    @State private var openedAt = Date()
    @State private var doneAt = Date()
    @Namespace private var ns

    private let doorTimeout: TimeInterval = 20
    private let doneTimeout: TimeInterval = 8

    private var book: Book { store.book(job.bookID)! }
    private var stepIndex: Int {
        switch phase {
        case .checking: 0
        case .opening: 1
        case .open: 2
        case .done: 3
        }
    }
    /// Page this reader saved last time they returned this book, if any.
    private var savedPage: Int? { store.bookmark(reader: job.name, book: job.bookID) }
    private var greeting: String { job.name.map { "Hi \($0)" } ?? "Good choice" }

    var body: some View {
        GeometryReader { geo in
            let cell = min((geo.size.height - 280) / 3.96, (geo.size.width * 0.56 - 72) / 4)
            ZStack {
                LinearGradient(colors: [K.ink, Color(hex: 0x0F141F)], startPoint: .top, endPoint: .bottom)

                VStack {
                    StepsBar(labels: Catalog.collectSteps, current: stepIndex)
                        .padding(.top, 34)
                    Spacer()
                }

                HStack(spacing: 48) {
                    VStack(spacing: 18) {
                        LockerWall(highlight: phase == .checking ? scanSlot : job.slotID,
                                   open: doorOpen ? [job.slotID] : [],
                                   hideBookIn: bookOut ? job.slotID : nil,
                                   cell: cell, namespace: ns)
                        Text("Car \(store.carNumber) library shelf")
                            .font(.k(16, .bold)).foregroundStyle(.white.opacity(0.4))
                    }

                    panel
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 48)
                .padding(.top, 60)

                if confetti { Confetti(origin: .init(x: 0.72, y: 0.4)) }
            }
        }
        .ignoresSafeArea()
        .task { await run() }
    }

    // MARK: Right-hand panel

    @ViewBuilder private var panel: some View {
        switch phase {
        case .checking, .opening:
            VStack(alignment: .leading, spacing: 22) {
                Text(greeting).font(.k(24, .bold)).foregroundStyle(K.yellow)
                Text(phase == .checking ? "Checking your pass" : "Unlocking door \(job.slotID)")
                    .font(.k(44, .bold)).foregroundStyle(.white)
                    .contentTransition(.opacity)
                HStack(spacing: 16) {
                    ProgressView().tint(.white).scaleEffect(1.5)
                    Text(phase == .checking ? "Finding \(book.title)" : "Stand clear of the door")
                        .font(.k(20)).foregroundStyle(.white.opacity(0.7))
                }
                if let code = job.code {
                    HStack(spacing: 14) {
                        Image(systemName: "qrcode").font(.system(size: 26))
                        Text("Pass \(code.prefix(3)) \(code.suffix(3))").font(.k(20, .bold).monospacedDigit())
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(hex: 0x3DDC97))
                            .opacity(phase == .opening ? 1 : 0)
                            .scaleEffect(phase == .opening ? 1 : 0.2)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 14)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity.combined(with: .move(edge: .trailing)))

        case .open:
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 24) {
                    if bookOut {
                        BookCover(book: book, width: 170)
                            .matchedGeometryEffect(id: "book-\(book.id)", in: ns)
                            .rotationEffect(.degrees(-4))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Door \(job.slotID) is open")
                            .font(.k(18, .bold)).foregroundStyle(K.ink)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(K.yellow, in: Capsule())
                        Text(book.title).font(.serif(32)).foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(book.author).font(.k(18)).foregroundStyle(.white.opacity(0.6))
                        if let r = book.rating {
                            HStack(spacing: 8) {
                                Stars(value: r, size: 15, color: K.yellow)
                                Text("\(book.reviews.count) review\(book.reviews.count == 1 ? "" : "s")")
                                    .font(.k(14)).foregroundStyle(.white.opacity(0.55))
                            }
                        }
                    }
                }
                if let savedPage, bookOut {
                    JumpBackIn(page: savedPage, book: book)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
                Text("Take your book from the glowing door. It closes by itself when you're done.")
                    .font(.k(21)).foregroundStyle(.white.opacity(0.8)).lineSpacing(3)
                HStack(spacing: 18) {
                    Button("I've got my book") { finish() }
                        .buttonStyle(KioskButtonStyle(kind: .yellow))
                    CountdownRing(start: openedAt, total: doorTimeout, size: 72, color: .white, track: .white.opacity(0.15))
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)

        case .done:
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .heavy)).foregroundStyle(K.ink)
                    .frame(width: 90, height: 90).background(K.yellow, in: Circle())
                    .transition(.scale)
                Text(job.name.map { "Enjoy the ride, \($0)!" } ?? "Enjoy the ride!")
                    .font(.serif(46)).foregroundStyle(.white)
                Text(savedPage.map { "Open it at page \($0) and you're right back where you left off. When you're done, leave it at any Between Stops kiosk." }
                     ?? "\(book.title) is yours for as long as you like. When you're done, leave it at any Between Stops kiosk.")
                    .font(.k(21)).foregroundStyle(.white.opacity(0.75)).lineSpacing(3)
                HStack(spacing: 12) {
                    funFact("map", "\(book.km) km", "travelled so far")
                    if let savedPage {
                        funFact("bookmark.fill", "Page \(savedPage)", "where you left off")
                    } else {
                        funFact("person.2.fill", "#\(book.trips.count + 1)", "reader on the line")
                    }
                    funFact("clock", book.readTime.replacingOccurrences(of: "About ", with: ""), "to read")
                }
                HStack(spacing: 18) {
                    Button("Done, back to home") { store.go(.home) }
                        .buttonStyle(KioskButtonStyle(kind: .yellow))
                        .frame(width: 300)
                    CountdownRing(start: doneAt, total: doneTimeout, size: 60, color: .white, track: .white.opacity(0.15))
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private func funFact(_ symbol: String, _ big: String, _ small: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol).foregroundStyle(K.yellow)
            Text(big).font(.k(22, .bold)).foregroundStyle(.white)
            Text(small).font(.k(14)).foregroundStyle(.white.opacity(0.55))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Sequence

    private func run() async {
        // Sweep a highlight across the doors like a slot machine, landing on ours.
        let ids = store.slots.map(\.id)
        let target = ids.firstIndex(of: job.slotID) ?? 0
        let steps = ids.count + target + 1
        for i in 0..<steps {
            scanSlot = ids[i % ids.count]
            let slowdown = Double(max(0, i - (steps - 6)))
            try? await Task.sleep(for: .milliseconds(55 + Int(slowdown * 45)))
        }
        scanSlot = job.slotID

        withAnimation(.spring(response: 0.4)) { phase = .opening }
        try? await Task.sleep(for: .seconds(0.9))

        AudioServicesPlaySystemSound(1100)
        doorOpen = true
        try? await Task.sleep(for: .seconds(0.7))

        openedAt = Date()
        withAnimation(.spring(response: 0.5)) { phase = .open }
        try? await Task.sleep(for: .seconds(0.15))
        withAnimation(.spring(response: 0.75, dampingFraction: 0.72)) { bookOut = true }
        AudioServicesPlaySystemSound(1025)
        confetti = true

        // Door closes on its own if nobody taps.
        try? await Task.sleep(for: .seconds(doorTimeout))
        if phase == .open { finish() }
    }

    private func finish() {
        guard phase == .open else { return }
        store.touch()
        doorOpen = false
        store.completeCollect(job)
        doneAt = Date()
        withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { phase = .done }
        Task {
            try? await Task.sleep(for: .seconds(doneTimeout))
            if case .collect(let j) = store.route, j.id == job.id { store.go(.home) }
        }
    }
}

/// "Welcome back" card shown when a reader collects a book they saved a page in.
struct JumpBackIn: View {
    let page: Int
    let book: Book
    @State private var fill = false

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(K.ink)
                .frame(width: 60, height: 60)
                .background(K.yellow, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .symbolEffect(.bounce, value: fill)
            VStack(alignment: .leading, spacing: 8) {
                Text("Jump back in at page \(page)").font(.k(22, .bold)).foregroundStyle(.white)
                ReadingProgress(page: fill ? page : 0, pages: book.pages)
                Text("\(Int(Double(page) / Double(book.pages) * 100))% through, saved to your account")
                    .font(.k(15)).foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(18)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(K.yellow.opacity(0.5), lineWidth: 1.5))
        .task {
            try? await Task.sleep(for: .seconds(0.3))
            fill = true
        }
    }
}
