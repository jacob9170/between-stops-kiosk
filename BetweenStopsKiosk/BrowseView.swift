import SwiftUI

/// Walk-up browsing: see every book behind the glass and borrow one without the app.
struct BrowseView: View {
    @Environment(KioskStore.self) private var store
    @State private var genre = "All"
    @State private var selected: Book?
    @State private var surprise = false
    @State private var shown = false

    private var list: [Book] {
        store.booksOnShelf.filter { b in
            switch genre {
            case "All": true
            case "Short reads": b.pages <= 100
            default: b.genre == genre
            }
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                TopBar()
                HStack(alignment: .bottom) {
                    ScreenTitle(title: "On the shelf", subtitle: "\(store.availableCount) books ready to borrow right now. Tap one to take a look.")
                    Button { surprise = true } label: {
                        Label("Surprise me", systemImage: "dice.fill")
                    }
                    .buttonStyle(KioskButtonStyle(kind: .ink, height: 64))
                    .frame(width: 230)
                }
                .padding(.horizontal, 32).padding(.top, 24)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Catalog.genres, id: \.self) { g in
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { genre = g }
                            } label: {
                                Text(g).font(.k(18, .bold))
                                    .foregroundStyle(genre == g ? .white : K.ink)
                                    .padding(.horizontal, 20).frame(height: 50)
                                    .background(genre == g ? K.ink : .white, in: Capsule())
                                    .overlay(Capsule().stroke(genre == g ? K.ink : K.line, lineWidth: 1.5))
                            }
                            .buttonStyle(PressStyle())
                        }
                    }
                    .padding(.horizontal, 32).padding(.vertical, 18)
                }

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170, maximum: 200), spacing: 26, alignment: .top)], spacing: 30) {
                        ForEach(Array(list.enumerated()), id: \.element.id) { i, b in
                            BookTile(book: b, held: store.isHeld(b.id)) { selected = b }
                                .offset(y: shown ? 0 : 40)
                                .opacity(shown ? 1 : 0)
                                .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(Double(i) * 0.04), value: shown)
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 32).padding(.bottom, 40)
                    if list.isEmpty {
                        Text("Nothing in \(genre.lowercased()) on this shelf right now. Try another one.")
                            .font(.k(20)).foregroundStyle(K.muted).padding(40)
                    }
                }
            }

            if let b = selected {
                BookDetail(book: b) { withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { selected = nil } }
                    .transition(.opacity)
                    .zIndex(2)
            }
            if surprise {
                SurpriseReel(books: store.booksOnShelf.filter { !store.isHeld($0.id) }) { pick in
                    surprise = false
                    if let pick { withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { selected = pick } }
                }
                .transition(.opacity)
                .zIndex(3)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: selected)
        .animation(.easeInOut(duration: 0.25), value: surprise)
        .onAppear { shown = true }
    }
}

struct BookTile: View {
    let book: Book
    let held: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                BookCover(book: book, width: 170)
                    .overlay(alignment: .topTrailing) {
                        if held {
                            Label("Held", systemImage: "lock.fill")
                                .font(.k(13, .bold)).foregroundStyle(K.ink)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(K.yellow, in: Capsule())
                                .padding(8)
                        }
                    }
                    .saturation(held ? 0.5 : 1)
                Text(book.title).font(.k(18, .bold)).foregroundStyle(K.ink).lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(book.author).font(.k(15)).foregroundStyle(K.muted)
                if let r = book.rating {
                    HStack(spacing: 6) {
                        Stars(value: r, size: 12)
                        Text("(\(book.reviews.count))").font(.k(13)).foregroundStyle(K.muted)
                    }
                }
            }
            .frame(width: 170, alignment: .leading)
        }
        .buttonStyle(PressStyle(scale: 0.95))
    }
}

struct BookDetail: View {
    @Environment(KioskStore.self) private var store
    let book: Book
    let close: () -> Void
    @State private var showAppQR = false
    @State private var shown = false

    private var slot: Slot? { store.slot(holding: book.id) }
    private var held: Bool { slot?.hold != nil }
    private var live: Book { store.book(book.id) ?? book }

    var body: some View {
        ZStack(alignment: .bottom) {
            K.ink.opacity(0.5).ignoresSafeArea().onTapGesture(perform: close)

            HStack(alignment: .top, spacing: 40) {
                VStack(spacing: 18) {
                    BookCover(book: book, width: 240)
                        .rotation3DEffect(.degrees(shown ? 0 : 25), axis: (x: 0, y: 1, z: 0))
                        .scaleEffect(shown ? 1 : 0.8)
                    if let slot {
                        Label("Behind door \(slot.id)", systemImage: "door.left.hand.closed")
                            .font(.k(16, .bold)).foregroundStyle(K.muted)
                    }
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(book.title).font(.serif(40)).foregroundStyle(K.ink)
                        Text(book.author).font(.k(20)).foregroundStyle(K.muted)
                        if let r = live.rating {
                            HStack(spacing: 10) {
                                Stars(value: r, size: 20)
                                Text(String(format: "%.1f", r)).font(.k(20, .bold))
                                Text("from \(live.reviews.count) reader\(live.reviews.count == 1 ? "" : "s")")
                                    .font(.k(16)).foregroundStyle(K.muted)
                            }
                        }
                        HStack(spacing: 8) {
                            Pill(text: book.genre)
                            Pill(text: "\(book.pages) pages")
                            Pill(text: book.readTime)
                            Pill(text: "\(live.km) km travelled", fg: K.ink, bg: K.held)
                        }
                        Text(book.blurb).font(.serif(22, .regular)).foregroundStyle(K.ink).lineSpacing(5)
                            .padding(.top, 4)

                        if let note = live.note {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Left by the last reader").font(.k(15, .bold)).foregroundStyle(K.muted)
                                Text("“\(note.text)”").font(.serif(20, .regular)).foregroundStyle(K.ink)
                                Text(note.by).font(.k(15)).foregroundStyle(K.muted)
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(K.cream, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }

                        if !live.reviews.isEmpty {
                            Text("Reviews").font(.k(20, .bold)).padding(.top, 6)
                            ForEach(live.reviews.prefix(3)) { r in ReviewCard(review: r) }
                        }

                        Text("Where it's been").font(.k(20, .bold)).padding(.top, 6)
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(live.trips.prefix(4).enumerated()), id: \.offset) { i, t in
                                HStack(alignment: .top, spacing: 14) {
                                    VStack(spacing: 0) {
                                        Circle().fill(i == 0 ? K.blue : .white)
                                            .overlay(Circle().stroke(K.blue, lineWidth: 3))
                                            .frame(width: 14, height: 14).padding(.top, 4)
                                        if i < min(4, live.trips.count) - 1 {
                                            Rectangle().fill(K.line).frame(width: 2).frame(maxHeight: .infinity)
                                        }
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(t.what).font(.k(17, .bold))
                                        Text(t.when).font(.k(15)).foregroundStyle(K.muted)
                                    }
                                    .padding(.bottom, 16)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 440)

                VStack(spacing: 14) {
                    if held {
                        VStack(spacing: 8) {
                            Image(systemName: "lock.fill").font(.system(size: 30))
                            Text("Held for another reader").font(.k(20, .bold)).multilineTextAlignment(.center)
                            Text("If they don't collect it in 30 minutes it goes back on the shelf.")
                                .font(.k(15)).foregroundStyle(K.muted).multilineTextAlignment(.center)
                        }
                        .padding(20)
                        .background(K.held, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    } else {
                        Button { store.borrowNow(book.id) } label: {
                            Label("Borrow now", systemImage: "lock.open.fill")
                        }
                        .buttonStyle(KioskButtonStyle(kind: .yellow, height: 80))
                        Text("Free, no card needed. Leave it on any library train when you're done.")
                            .font(.k(15)).foregroundStyle(K.muted).multilineTextAlignment(.center)
                    }
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { showAppQR.toggle() }
                    } label: {
                        Label(showAppQR ? "Hide" : "Get the app", systemImage: "iphone")
                    }
                    .buttonStyle(KioskButtonStyle(kind: .ghost, height: 60))
                    if showAppQR {
                        VStack(spacing: 8) {
                            QRView(text: "https://rjschweitz.github.io/test").frame(width: 150, height: 150)
                            Text("Scan to reserve books for your next trip").font(.k(14)).foregroundStyle(K.muted)
                                .multilineTextAlignment(.center)
                        }
                        .padding(14)
                        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .transition(.scale.combined(with: .opacity))
                    }
                    Spacer(minLength: 0)
                    Button("Close", action: close)
                        .buttonStyle(KioskButtonStyle(kind: .ink, height: 60))
                }
                .frame(width: 260)
            }
            .frame(height: 500, alignment: .top)
            .padding(36)
            .frame(maxWidth: .infinity)
            .background(K.bg, in: UnevenRoundedRectangle(topLeadingRadius: 40, topTrailingRadius: 40, style: .continuous))
            .offset(y: shown ? 0 : 700)
            .ignoresSafeArea(edges: .bottom)
        }
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) { shown = true } }
    }
}

/// Slot machine style picker. Covers whizz past, slow down and land on one.
struct SurpriseReel: View {
    let books: [Book]
    let done: (Book?) -> Void
    @State private var index = 0
    @State private var landed = false
    @State private var confetti = false

    var body: some View {
        ZStack {
            K.ink.opacity(0.94).ignoresSafeArea()
            VStack(spacing: 28) {
                Text(landed ? "How about this one?" : "Picking something for you…")
                    .font(.k(34, .bold)).foregroundStyle(.white)
                    .contentTransition(.opacity)
                ZStack {
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .fill(.white.opacity(0.06))
                        .frame(width: 320, height: 400)
                    if !books.isEmpty {
                        let b = books[index % books.count]
                        BookCover(book: b, width: 220)
                            .id(index)
                            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                                    removal: .move(edge: .bottom).combined(with: .opacity)))
                            .scaleEffect(landed ? 1.08 : 1)
                    }
                }
                .frame(width: 320, height: 400)
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).stroke(K.yellow, lineWidth: landed ? 5 : 0))

                HStack(spacing: 16) {
                    Button("Spin again") { Task { await spin() } }
                        .buttonStyle(KioskButtonStyle(kind: .ghostDark, height: 64))
                    Button("Take a look") { done(books.isEmpty ? nil : books[index % books.count]) }
                        .buttonStyle(KioskButtonStyle(kind: .yellow, height: 64))
                }
                .frame(width: 520)
                .opacity(landed ? 1 : 0)
                Button("Close") { done(nil) }
                    .font(.k(18, .bold)).foregroundStyle(.white.opacity(0.6))
            }
            if confetti { Confetti(origin: .init(x: 0.5, y: 0.45), count: 70) }
        }
        .task { await spin() }
    }

    private func spin() async {
        guard !books.isEmpty else { return }
        landed = false
        confetti = false
        let target = Int.random(in: 14...24)
        for i in 0..<target {
            withAnimation(.easeOut(duration: 0.12)) { index += 1 }
            KioskStore.shared.touch()
            try? await Task.sleep(for: .milliseconds(60 + i * i / 2 * 3))
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { landed = true }
        confetti = true
    }
}

struct ReviewCard: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Stars(value: Double(review.stars), size: 14)
                Spacer()
                Text("\(review.by) · \(review.when)").font(.k(14)).foregroundStyle(K.muted)
            }
            if !review.text.isEmpty {
                Text(review.text).font(.serif(18, .regular)).foregroundStyle(K.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !review.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(review.tags, id: \.self) { t in
                        Text(t).font(.k(13, .bold))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(K.grey, in: Capsule())
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
