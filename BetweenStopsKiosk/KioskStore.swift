import SwiftUI
import Observation
import AVFoundation

@MainActor
@Observable
final class KioskStore {
    static let shared = KioskStore()

    // Navigation
    var route: Route = .attract
    var alert: KioskAlert?
    var toast: String?

    // Shelf
    var books: [Book] = Catalog.books
    var slots: [Slot] = Catalog.initialSlots()
    var reservations: [Reservation] = Catalog.initialReservations()
    var openDoors: Set<String> = []

    // Accounts
    var loans: [String: String] = Catalog.initialLoans
    var bookmarks: [String: [String: Int]] = Catalog.initialBookmarks

    // Settings
    var textScale: CGFloat = 1
    var showDemoPasses = true
    var hasCamera: Bool = AVCaptureDevice.default(for: .video) != nil

    // Journey (the train this kiosk rides on). Demo: a stop every 40 seconds.
    var nextStop = 3
    var legStart = Date()
    let legLength: TimeInterval = 40
    let carNumber = 2

    // Today's numbers, ticked up as people use the kiosk
    var borrowedToday = 37
    var returnedToday = 29
    var kmThisWeek = 18_420

    // Idle handling
    var lastTouch = Date()
    var stillThere = false

    private var toastTask: Task<Void, Never>?

    // MARK: Lookups

    func book(_ id: String?) -> Book? { books.first { $0.id == id } }
    func slot(holding bookID: String) -> Slot? { slots.first { $0.bookID == bookID } }
    var booksOnShelf: [Book] { slots.compactMap { book($0.bookID) } }
    var availableCount: Int { slots.filter { $0.bookID != nil && $0.hold == nil }.count }
    var emptySlots: [Slot] { slots.filter { $0.bookID == nil } }

    var currentStation: String { Catalog.stations[(nextStop - 1 + Catalog.stations.count) % Catalog.stations.count] }
    var nextStation: String { Catalog.stations[nextStop % Catalog.stations.count] }
    var terminus: String { Catalog.stations.last! }

    func isHeld(_ bookID: String) -> Bool { slot(holding: bookID)?.hold != nil }

    // MARK: Navigation

    func go(_ r: Route) {
        touch()
        alert = nil
        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { route = r }
    }

    func touch() {
        lastTouch = Date()
        if stillThere { withAnimation(.spring) { stillThere = false } }
    }

    func showToast(_ text: String) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { toast = text }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.8))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut) { self.toast = nil }
        }
    }

    func showAlert(_ a: KioskAlert) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { alert = a }
    }

    /// Called every second from the root view.
    func tick() {
        if Date().timeIntervalSince(legStart) >= legLength {
            nextStop = (nextStop + 1) % Catalog.stations.count
            legStart = Date()
        }

        let idle = Date().timeIntervalSince(lastTouch)
        switch route {
        case .attract, .collect:
            return
        case .home:
            if idle > 90 { go(.attract) }
        default:
            let limit: TimeInterval = route == .staff ? 120 : 45
            if idle > limit + 12 { stillThere = false; go(.home) }
            else if idle > limit, !stillThere { withAnimation(.spring) { stillThere = true } }
        }
    }

    // MARK: Scanning

    /// Entry point for anything the camera, clipboard, keypad or demo buttons produce.
    func handleScan(_ raw: String, expectingReturn: Bool = false) {
        touch()
        guard let payload = ScanPayload.parse(raw, books: books) else {
            showAlert(KioskAlert(symbol: "qrcode", title: "That code isn't one of ours",
                                 message: "Open the Between Stops app, tap your reservation and hold the QR code up to the camera."))
            return
        }
        switch payload {
        case .returnBook(let id):
            startReturn(id)
        case .quick(let pin):
            if expectingReturn {
                showAlert(KioskAlert(symbol: "arrow.uturn.left", title: "That's a quick code",
                                     message: "Quick codes are for collecting. To return a book, scan the barcode on its back cover."))
                return
            }
            collectQuick(pin)
        case let .collect(code, bookID, name, expires):
            if expectingReturn {
                showAlert(KioskAlert(symbol: "arrow.uturn.left", title: "That's a reservation pass",
                                     message: "To return a book, scan the barcode on its back cover. To collect a book, go back and scan your pass on the main screen."))
                return
            }
            collect(code: code, bookID: bookID, name: name, expires: expires)
        }
    }

    func collect(code: String?, bookID: String?, name: String?, expires: Date?) {
        if let expires, expires < Date() {
            return expired(bookID)
        }
        if let code, let r = reservations.first(where: { $0.code == code }) {
            if r.collected {
                return showAlert(KioskAlert(symbol: "checkmark.seal", title: "Already collected",
                                            message: "\(book(r.bookID)?.title ?? "This book") was collected with this pass earlier. Enjoy the read!",
                                            bookID: r.bookID))
            }
            if r.expires < Date() { return expired(r.bookID) }
            guard let s = slot(holding: r.bookID) else { return notHere(r.bookID) }
            return go(.collect(CollectJob(bookID: r.bookID, slotID: s.id, name: r.name, code: r.code)))
        }
        // A pass made by the generator or phone that this kiosk hasn't synced yet. Trust the book id.
        guard let bookID, book(bookID) != nil else {
            return showAlert(KioskAlert(symbol: "number", title: "We couldn't find that code",
                                        message: "Check the six digit code in the app and try again. Codes are only valid for 30 minutes."))
        }
        guard let s = slot(holding: bookID) else { return notHere(bookID) }
        if let hold = s.hold, hold != code {
            return showAlert(KioskAlert(symbol: "lock.fill", title: "Someone else has this one",
                                        message: "\(book(bookID)!.title) is held for another reader. Browse the shelf for something else to read.",
                                        bookID: bookID))
        }
        if let code {
            reservations.append(Reservation(code: code, bookID: bookID, name: name ?? "Reader", expires: Date().addingTimeInterval(30 * 60)))
        }
        go(.collect(CollectJob(bookID: bookID, slotID: s.id, name: name, code: code)))
    }

    /// 4 digit quick code from the phone. Known reservations match exactly; otherwise the
    /// first two digits tell us which book was booked.
    func collectQuick(_ pin: String) {
        if let r = reservations.first(where: { $0.pin == pin }) {
            return collect(code: r.code, bookID: r.bookID, name: r.name, expires: nil)
        }
        guard let n = Int(pin.prefix(2)), let b = books.first(where: { $0.quickNumber == n }) else {
            return showAlert(KioskAlert(symbol: "number", title: "We couldn't find that quick code",
                                        message: "Check the 4 digit quick code under your QR in the app. Codes last 30 minutes."))
        }
        collect(code: nil, bookID: b.id, name: nil, expires: nil)
    }

    private func expired(_ bookID: String?) {
        showAlert(KioskAlert(symbol: "clock.badge.exclamationmark", title: "This reservation has expired",
                             message: "Holds last 30 minutes. If the book is still on the shelf you can borrow it straight away from Browse.",
                             bookID: bookID))
    }

    private func notHere(_ bookID: String) {
        let title = book(bookID)?.title ?? "That book"
        showAlert(KioskAlert(symbol: "tram.fill", title: "Wrong train",
                             message: "\(title) is riding a different train right now. Check the app for the train and car it's on.",
                             bookID: bookID))
    }

    /// Walk-up borrow from Browse, no reservation needed.
    func borrowNow(_ bookID: String) {
        guard let s = slot(holding: bookID), s.hold == nil else { return }
        go(.collect(CollectJob(bookID: bookID, slotID: s.id, name: nil, code: nil)))
    }

    /// The door has opened and the reader has taken the book.
    func completeCollect(_ job: CollectJob) {
        guard let i = slots.firstIndex(where: { $0.id == job.slotID }) else { return }
        slots[i].bookID = nil
        slots[i].hold = nil
        if let code = job.code, let r = reservations.firstIndex(where: { $0.code == code }) {
            reservations[r].collected = true
        }
        loans[job.bookID] = job.name ?? "Reader"
        if let b = books.firstIndex(where: { $0.id == job.bookID }) {
            books[b].trips.insert(Trip(what: "Collected from car \(carNumber) at \(currentStation)\(job.name.map { " by \($0)" } ?? "")", when: "Just now"), at: 0)
        }
        borrowedToday += 1
    }

    // MARK: Returns

    func startReturn(_ bookID: String) {
        guard book(bookID) != nil else {
            return showAlert(KioskAlert(symbol: "barcode", title: "We don't know that book",
                                        message: "Only books with a Between Stops sticker can go in the kiosk."))
        }
        if slot(holding: bookID) != nil {
            return showAlert(KioskAlert(symbol: "books.vertical.fill", title: "That book is already on the shelf",
                                        message: "Looks like it's already in one of our doors. Try scanning a different book.", bookID: bookID))
        }
        guard !emptySlots.isEmpty else {
            return showAlert(KioskAlert(symbol: "tray.full.fill", title: "This shelf is full",
                                        message: "Every door is in use. Car 5 has a library too, or keep it for your next trip."))
        }
        go(.returnBook(bookID))
    }

    /// Picks the door a returned book should go in. Middle row first, it's the easiest to reach.
    func doorForReturn() -> Slot? {
        emptySlots.sorted { a, b in
            let rank: (Slot) -> Int = { $0.id.hasPrefix("B") ? 0 : ($0.id.hasPrefix("A") ? 1 : 2) }
            return (rank(a), a.id) < (rank(b), b.id)
        }.first
    }

    func completeReturn(_ bookID: String, slotID: String, note: ReaderNote?) {
        guard let i = slots.firstIndex(where: { $0.id == slotID }) else { return }
        slots[i].bookID = bookID
        slots[i].hold = nil
        if let b = books.firstIndex(where: { $0.id == bookID }) {
            books[b].trips.insert(Trip(what: "Returned to car \(carNumber) at \(currentStation)", when: "Just now"), at: 0)
            books[b].km += Int.random(in: 8...26)
            if let note { books[b].note = note }
        }
        returnedToday += 1
        kmThisWeek += 14
    }

    // MARK: Bookmarks & reviews

    func bookmark(reader: String?, book: String) -> Int? {
        guard let reader else { return nil }
        return bookmarks[reader]?[book]
    }

    func saveBookmark(reader: String, book: String, page: Int) {
        bookmarks[reader, default: [:]][book] = page
    }

    func addReview(_ r: Review, to bookID: String) {
        guard let i = books.firstIndex(where: { $0.id == bookID }) else { return }
        books[i].reviews.insert(r, at: 0)
        let text = r.text.isEmpty ? r.tags.first : r.text
        if let text { books[i].note = ReaderNote(text: text, by: r.by) }
        // Finished it, so there's no page to come back to.
        bookmarks[r.by]?[bookID] = nil
    }

    /// The book is back on the shelf and no longer out with anyone.
    func endLoan(_ bookID: String) { loans[bookID] = nil }

    // MARK: Staff

    func resetDemo() {
        books = Catalog.books
        slots = Catalog.initialSlots()
        reservations = Catalog.initialReservations()
        openDoors = []
        loans = Catalog.initialLoans
        bookmarks = Catalog.initialBookmarks
        borrowedToday = 37
        returnedToday = 29
        showToast("Shelf restocked and demo data reset")
    }
}
