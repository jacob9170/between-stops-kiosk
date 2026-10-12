import SwiftUI
import AudioToolbox

/// Return flow: scan the book, an empty door opens, pop it in, leave a note for the next reader.
struct ReturnView: View {
    @Environment(KioskStore.self) private var store
    let bookID: String?

    var body: some View {
        if let bookID, let book = store.book(bookID) {
            PlaceBookView(book: book)
        } else {
            scanStep
        }
    }

    private var scanStep: some View {
        VStack(spacing: 0) {
            TopBar()
            HStack(spacing: 28) {
                VStack(spacing: 16) {
                    Viewfinder(hint: "Hold the back cover up to the camera", expectingReturn: true)
                    if !store.hasCamera || store.showDemoPasses {
                        DemoScanTray(returning: true)
                    }
                }
                .padding(24)
                .background(K.ink, in: RoundedRectangle(cornerRadius: 34, style: .continuous))

                VStack(alignment: .leading, spacing: 26) {
                    ScreenTitle(title: "Return a book", subtitle: "Thanks for passing it on.")
                    step(1, "Find the barcode", "It's on the Between Stops sticker on the back cover.")
                    step(2, "Hold it up to the camera", "We'll open an empty door for you.")
                    step(3, "Pop it in and leave a note", "The next reader sees what you thought.")
                    Spacer()
                    Label("Any Between Stops book can go in any library train, not just the one you got it from.",
                          systemImage: "tram.fill")
                        .font(.k(17)).foregroundStyle(K.muted)
                        .padding(18)
                        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .frame(width: 400)
            }
            .padding(28)
        }
    }

    private func step(_ n: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text("\(n)").font(.k(22, .bold)).foregroundStyle(K.ink)
                .frame(width: 46, height: 46).background(K.yellow, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.k(22, .bold))
                Text(detail).font(.k(17)).foregroundStyle(K.muted)
            }
        }
    }
}

struct PlaceBookView: View {
    @Environment(KioskStore.self) private var store
    let book: Book

    enum Phase: Equatable { case placing, choice, review, bookmark, thanks }
    enum Outcome: Equatable { case plain, reviewed(Int), saved(Int) }

    @State private var phase: Phase = .placing
    @State private var outcome: Outcome = .plain
    @State private var slotID: String?
    @State private var doorOpen = false
    @State private var bookIn = false
    @State private var reader: String?
    @State private var thanksAt = Date()

    // Review
    @State private var stars = 0
    @State private var tags: Set<String> = []
    @State private var reviewText = ""
    @State private var anonymous = false
    @FocusState private var typing: Bool

    // Bookmark
    @State private var pageText = ""

    private var who: String { reader ?? "Reader" }
    private var page: Int { Int(pageText) ?? 0 }
    private var pageValid: Bool { page > 0 && page <= book.pages }
    private var savedPage: Int? { store.bookmark(reader: reader, book: book.id) }

    var body: some View {
        GeometryReader { geo in
            let cell = min((geo.size.height - 200) / 3.96, (geo.size.width * 0.52 - 72) / 4)
            ZStack {
                LinearGradient(colors: [K.ink, Color(hex: 0x0F141F)], startPoint: .top, endPoint: .bottom)
                    .onTapGesture { typing = false }

                if phase == .placing || phase == .thanks {
                    HStack(spacing: 48) {
                        ZStack {
                            LockerWall(highlight: slotID, open: doorOpen ? [slotID ?? ""] : [], cell: cell)
                            if phase == .placing, let slotID, !bookIn {
                                DropHint(slotID: slotID, cell: cell)
                            }
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        Group {
                            if phase == .placing { placingPanel } else { thanksPanel }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 48)
                } else {
                    followUp
                        .padding(.horizontal, 56)
                        .padding(.vertical, 40)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }

                if phase == .thanks { Confetti(origin: .init(x: 0.72, y: 0.35), count: 90) }
            }
        }
        .ignoresSafeArea(.container)
        .task {
            reader = store.loans[book.id]
            slotID = store.doorForReturn()?.id
            try? await Task.sleep(for: .seconds(0.6))
            AudioServicesPlaySystemSound(1100)
            doorOpen = true
        }
    }

    // MARK: Placing

    private var placingPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 20) {
                BookCover(book: book, width: 120)
                    .offset(x: bookIn ? -220 : 0)
                    .scaleEffect(bookIn ? 0.4 : 1)
                    .opacity(bookIn ? 0 : 1)
                VStack(alignment: .leading, spacing: 6) {
                    Label("Found it", systemImage: "checkmark.circle.fill")
                        .font(.k(17, .bold)).foregroundStyle(Color(hex: 0x3DDC97))
                    Text(book.title).font(.serif(30)).foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(book.author).font(.k(18)).foregroundStyle(.white.opacity(0.6))
                }
            }
            Text("Pop it into door \(slotID ?? "")")
                .font(.k(40, .bold)).foregroundStyle(.white)
            Text("The glowing door is open. Slide the book in spine first, then tap below.")
                .font(.k(20)).foregroundStyle(.white.opacity(0.75))
            Button("It's in, close the door") { placed() }
                .buttonStyle(KioskButtonStyle(kind: .yellow))
            Button("Cancel") { store.go(.home) }
                .buttonStyle(KioskButtonStyle(kind: .ghostDark, height: 60))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Follow-up screens (choice, review, bookmark)

    private var followUp: some View {
        HStack(alignment: .top, spacing: 48) {
            VStack(alignment: .leading, spacing: 14) {
                BookCover(book: book, width: 210)
                    .rotationEffect(.degrees(-3))
                Text(book.title).font(.serif(26)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(book.author).font(.k(17)).foregroundStyle(.white.opacity(0.6))
                if let r = store.book(book.id)?.rating {
                    HStack(spacing: 8) {
                        Stars(value: r, size: 15, color: K.yellow)
                        Text(String(format: "%.1f", r)).font(.k(15, .bold)).foregroundStyle(.white.opacity(0.7))
                    }
                }
                Label("Safely back in door \(slotID ?? "")", systemImage: "lock.fill")
                    .font(.k(15, .bold)).foregroundStyle(Color(hex: 0x3DDC97))
                    .padding(.top, 6)
            }
            .frame(width: 240, alignment: .leading)

            Group {
                switch phase {
                case .choice: choicePanel
                case .review: reviewPanel
                case .bookmark: bookmarkPanel
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private var choicePanel: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(reader.map { "Thanks, \($0)!" } ?? "Thanks for bringing it back!")
                .font(.k(22, .bold)).foregroundStyle(K.yellow)
            Text("Did you finish it?").font(.k(48, .bold)).foregroundStyle(.white)

            HStack(spacing: 18) {
                ChoiceCard(symbol: "checkmark.seal.fill", title: "Finished it",
                           subtitle: "Rate it and leave a review for the next reader",
                           highlighted: true) { go(.review) }
                ChoiceCard(symbol: "bookmark.fill", title: "Still reading",
                           subtitle: reader.map { "Save your page to \($0)'s account and jump back in next time" }
                                ?? "Save your page and jump back in next time",
                           highlighted: false) {
                    pageText = savedPage.map(String.init) ?? ""
                    go(.bookmark)
                }
            }
            .frame(height: 250)

            if let savedPage {
                Label("Last time you saved page \(savedPage)", systemImage: "bookmark")
                    .font(.k(17)).foregroundStyle(.white.opacity(0.6))
            }

            Button("Just return it") { thank(.plain) }
                .buttonStyle(KioskButtonStyle(kind: .ghostDark, height: 60))
                .frame(width: 260)
        }
    }

    private var reviewPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Rate it").font(.k(44, .bold)).foregroundStyle(.white)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3)) { anonymous.toggle() }
                } label: {
                    Label(anonymous ? "Posting anonymously" : "Posting as \(who)",
                          systemImage: anonymous ? "eye.slash.fill" : "person.crop.circle.fill")
                        .font(.k(16, .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .background(.white.opacity(0.1), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                        .contentTransition(.opacity)
                }
                .buttonStyle(PressStyle())
                .accessibilityHint("Switches between posting with your name and posting anonymously")
            }

            StarPicker(stars: $stars)

            Text("What stood out?").font(.k(18, .bold)).foregroundStyle(.white.opacity(0.75))
            MultiChips(items: Catalog.tagOptions, selected: $tags)

            HStack(alignment: .top, spacing: 12) {
                TextField("", text: $reviewText,
                          prompt: Text("Write a review (optional)").foregroundStyle(.white.opacity(0.4)),
                          axis: .vertical)
                    .lineLimit(2...4)
                    .font(.k(19))
                    .foregroundStyle(.white)
                    .tint(K.yellow)
                    .focused($typing)
                    .padding(16)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(typing ? K.yellow : .clear, lineWidth: 2))
                    .onChange(of: reviewText) { _, v in if v.count > 240 { reviewText = String(v.prefix(240)) } }
                if typing {
                    Button("Done") { typing = false }
                        .font(.k(18, .bold)).foregroundStyle(K.ink)
                        .padding(.horizontal, 18).frame(height: 56)
                        .background(K.yellow, in: Capsule())
                }
            }

            HStack(spacing: 14) {
                Button("Skip") { thank(.plain) }
                    .buttonStyle(KioskButtonStyle(kind: .ghostDark, height: 66))
                    .frame(width: 180)
                Button { submitReview() } label: {
                    Label("Post my review", systemImage: "paperplane.fill")
                }
                .buttonStyle(KioskButtonStyle(kind: .yellow, height: 66))
                .disabled(stars == 0)
                .opacity(stars == 0 ? 0.45 : 1)
            }
        }
    }

    private var bookmarkPanel: some View {
        HStack(alignment: .top, spacing: 40) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Which page are you up to?").font(.k(40, .bold)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("We'll save it to \(reader.map { "\($0)'s" } ?? "your") account. Next time you collect this book on any train, we'll take you straight back.")
                    .font(.k(18)).foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Page").font(.k(26, .bold)).foregroundStyle(.white.opacity(0.6))
                    Text(pageText.isEmpty ? "–" : pageText)
                        .font(.system(size: 76, weight: .bold).monospacedDigit())
                        .foregroundStyle(pageText.isEmpty || pageValid ? K.yellow : Color(hex: 0xFFB4A6))
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: pageText)
                    Text("of \(book.pages)").font(.k(22)).foregroundStyle(.white.opacity(0.5))
                }

                ReadingProgress(page: pageValid ? page : 0, pages: book.pages)

                Group {
                    if !pageText.isEmpty && !pageValid {
                        Label("This book only has \(book.pages) pages", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color(hex: 0xFFB4A6))
                    } else if pageValid {
                        Label("\(Int(Double(page) / Double(book.pages) * 100))% through, about \(timeLeft) to go",
                              systemImage: "clock")
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        Label("Tip: it's the last page number you read", systemImage: "lightbulb")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .font(.k(17, .bold))

                Button {
                    go(.review)
                } label: {
                    Label("Actually, I finished it. Review it", systemImage: "checkmark.seal")
                        .font(.k(17, .bold)).foregroundStyle(K.yellow)
                }
                .buttonStyle(PressStyle())
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 14) {
                NumberPad(text: $pageText, maxLength: 4, dark: true, keyHeight: 74)
                Button { savePage() } label: {
                    Label("Save my page", systemImage: "bookmark.fill")
                }
                .buttonStyle(KioskButtonStyle(kind: .yellow, height: 74))
                .disabled(!pageValid)
                .opacity(pageValid ? 1 : 0.45)
                Button("Back") { go(.choice) }
                    .font(.k(17, .bold)).foregroundStyle(.white.opacity(0.6))
            }
            .frame(width: 330)
        }
    }

    private var timeLeft: String {
        let m = book.minutesLeft(fromPage: page)
        return m < 60 ? "\(m) min" : "\(Int((Double(m) / 60).rounded())) hr"
    }

    // MARK: Thanks

    private var thanksPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            Group {
                switch outcome {
                case .plain:
                    Image(systemName: "heart.fill").font(.system(size: 38))
                case .reviewed:
                    Image(systemName: "star.fill").font(.system(size: 38))
                case .saved:
                    Image(systemName: "bookmark.fill").font(.system(size: 38))
                }
            }
            .foregroundStyle(K.ink)
            .frame(width: 90, height: 90).background(K.yellow, in: Circle())

            switch outcome {
            case .plain:
                Text("Thanks for passing it on").font(.serif(44)).foregroundStyle(.white)
                Text("\(book.title) is back on the shelf in door \(slotID ?? ""). It has now travelled \(store.book(book.id)?.km ?? book.km) km.")
                    .font(.k(21)).foregroundStyle(.white.opacity(0.75)).lineSpacing(3)
            case .reviewed(let n):
                Text("Thanks for the review!").font(.serif(44)).foregroundStyle(.white)
                Stars(value: Double(n), size: 30, color: K.yellow)
                Text("Your \(n) star review is now on \(book.title) for the next reader to see.")
                    .font(.k(21)).foregroundStyle(.white.opacity(0.75)).lineSpacing(3)
            case .saved(let p):
                Text("Page \(p) saved").font(.serif(44)).foregroundStyle(.white)
                Text("It's on \(reader.map { "\($0)'s" } ?? "your") account. Collect \(book.title) again on any train and we'll take you straight back to page \(p).")
                    .font(.k(21)).foregroundStyle(.white.opacity(0.75)).lineSpacing(3)
                ReadingProgress(page: p, pages: book.pages).frame(maxWidth: 420)
            }

            HStack(spacing: 18) {
                Button("Return another") { store.go(.returnBook(nil)) }
                    .buttonStyle(KioskButtonStyle(kind: .yellow))
                Button("Done") { store.go(.home) }
                    .buttonStyle(KioskButtonStyle(kind: .white))
                CountdownRing(start: thanksAt, total: 10, size: 60, color: .white, track: .white.opacity(0.15))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Actions

    private func go(_ p: Phase) {
        typing = false
        store.touch()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { phase = p }
    }

    private func placed() {
        guard let slotID else { return }
        withAnimation(.easeIn(duration: 0.45)) { bookIn = true }
        Task {
            try? await Task.sleep(for: .seconds(0.45))
            store.completeReturn(book.id, slotID: slotID, note: nil)
            try? await Task.sleep(for: .seconds(0.25))
            doorOpen = false
            AudioServicesPlaySystemSound(1104)
            try? await Task.sleep(for: .seconds(0.6))
            go(.choice)
        }
    }

    private func submitReview() {
        guard stars > 0 else { return }
        let text = reviewText.trimmingCharacters(in: .whitespacesAndNewlines)
        let by = anonymous ? "A reader at \(store.currentStation)" : who
        store.addReview(Review(stars: stars, text: text, tags: Catalog.tagOptions.filter(tags.contains), by: by), to: book.id)
        if let reader { store.bookmarks[reader]?[book.id] = nil }
        thank(.reviewed(stars))
    }

    private func savePage() {
        guard pageValid else { return }
        store.saveBookmark(reader: who, book: book.id, page: page)
        thank(.saved(page))
    }

    private func thank(_ o: Outcome) {
        typing = false
        outcome = o
        store.endLoan(book.id)
        thanksAt = Date()
        AudioServicesPlaySystemSound(1025)
        withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { phase = .thanks }
        Task {
            try? await Task.sleep(for: .seconds(10))
            if store.route == .returnBook(book.id), phase == .thanks { store.go(.home) }
        }
    }
}

/// One of the two big "Did you finish it?" answers.
private struct ChoiceCard: View {
    let symbol: String
    let title: String
    let subtitle: String
    let highlighted: Bool
    let action: () -> Void
    @State private var bounce = 0

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 40, weight: .semibold))
                    .symbolEffect(.bounce, value: bounce)
                Spacer()
                Text(title).font(.k(30, .bold))
                Text(subtitle).font(.k(17)).opacity(0.75)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(highlighted ? K.ink : .white)
            .padding(26)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(highlighted ? K.yellow : .white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(highlighted ? .clear : .white.opacity(0.15), lineWidth: 2))
        }
        .buttonStyle(PressStyle())
        .task {
            try? await Task.sleep(for: .seconds(highlighted ? 0.4 : 0.8))
            bounce += 1
        }
    }
}

/// Five big tappable stars that pop as they fill.
struct StarPicker: View {
    @Binding var stars: Int
    private let labels = ["Tap to rate", "Not for me", "It was OK", "Good read", "Really good", "Loved it!"]

    var body: some View {
        HStack(spacing: 18) {
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { stars = i }
                    } label: {
                        Image(systemName: i <= stars ? "star.fill" : "star")
                            .font(.system(size: 50, weight: .semibold))
                            .foregroundStyle(i <= stars ? K.yellow : .white.opacity(0.3))
                            .scaleEffect(i <= stars ? 1.08 : 1)
                            .rotationEffect(.degrees(i <= stars ? 0 : -12))
                            .animation(.spring(response: 0.35, dampingFraction: 0.45).delay(Double(i) * 0.04), value: stars)
                            .frame(width: 66, height: 66)
                    }
                    .buttonStyle(PressStyle(scale: 0.85))
                    .accessibilityLabel("\(i) star\(i == 1 ? "" : "s")")
                }
            }
            Text(labels[stars])
                .font(.k(22, .bold))
                .foregroundStyle(stars == 0 ? .white.opacity(0.4) : .white)
                .id(stars)
                .transition(.push(from: .bottom))
        }
    }
}

/// Thin bar showing how far through the book a page is.
struct ReadingProgress: View {
    let page: Int
    let pages: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule().fill(K.yellow)
                    .frame(width: max(0, geo.size.width * CGFloat(page) / CGFloat(max(1, pages))))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: page)
            }
        }
        .frame(height: 12)
    }
}

/// Wrapping chips where several can be picked.
struct MultiChips: View {
    let items: [String]
    @Binding var selected: Set<String>

    var body: some View {
        FlowLayout(spacing: 10) {
            ForEach(items, id: \.self) { s in
                let on = selected.contains(s)
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        if on { selected.remove(s) } else { selected.insert(s) }
                    }
                } label: {
                    Label(s, systemImage: on ? "checkmark" : "plus")
                        .font(.k(16, .bold))
                        .foregroundStyle(on ? K.ink : .white)
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .background(on ? K.yellow : .white.opacity(0.1), in: Capsule())
                }
                .buttonStyle(PressStyle())
            }
        }
    }
}

/// Bouncing arrow over the open door.
private struct DropHint: View {
    @Environment(KioskStore.self) private var store
    let slotID: String
    let cell: CGFloat
    @State private var bounce = false

    var body: some View {
        let ids = store.slots.map(\.id)
        let i = ids.firstIndex(of: slotID) ?? 0
        let col = CGFloat(i % 4), row = CGFloat(i / 4)
        let h = cell * 1.32
        let wallW = cell * 4 + 36 + 36, wallH = h * 3 + 24 + 36
        Image(systemName: "arrow.down")
            .font(.system(size: 34, weight: .heavy))
            .foregroundStyle(K.ink)
            .frame(width: 60, height: 60)
            .background(K.yellow, in: Circle())
            .shadow(color: K.yellow.opacity(0.6), radius: 14)
            .offset(x: 18 + col * (cell + 12) + cell / 2 - wallW / 2,
                    y: 18 + row * (h + 12) - wallH / 2 - (bounce ? 30 : 10))
            .onAppear { withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { bounce = true } }
            .allowsHitTesting(false)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal.width ?? .infinity, subviews)
        let h = rows.map { $0.h }.reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? rows.map(\.w).max() ?? 0, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(bounds.width, subviews) {
            var x = bounds.minX
            for i in row.items {
                let s = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
            y += row.h + spacing
        }
    }

    private func arrange(_ width: CGFloat, _ subviews: Subviews) -> [(items: [Int], w: CGFloat, h: CGFloat)] {
        var rows: [(items: [Int], w: CGFloat, h: CGFloat)] = [([], 0, 0)]
        for i in subviews.indices {
            let s = subviews[i].sizeThatFits(.unspecified)
            if rows[rows.count - 1].w + s.width > width, !rows[rows.count - 1].items.isEmpty {
                rows.append(([], 0, 0))
            }
            rows[rows.count - 1].items.append(i)
            rows[rows.count - 1].w += s.width + spacing
            rows[rows.count - 1].h = max(rows[rows.count - 1].h, s.height)
        }
        return rows
    }
}
