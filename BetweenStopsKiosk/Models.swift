import SwiftUI

enum CoverArt { case sun, waves, stripes, circle, dots, bird, moon, lines }

struct Trip: Hashable {
    let what: String
    let when: String
}

struct ReaderNote: Hashable {
    let text: String
    let by: String
}

/// A star review left at the kiosk after finishing a book.
struct Review: Identifiable, Hashable {
    let id = UUID()
    let stars: Int
    let text: String
    var tags: [String] = []
    let by: String
    var when: String = "Just now"
}

struct Book: Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let genre: String
    let pages: Int
    let c1: Color
    let c2: Color
    let art: CoverArt
    let blurb: String
    var trips: [Trip]
    var note: ReaderNote?
    var km: Int
    let barcode: String
    var reviews: [Review] = []

    /// Two digit number used as the start of a 4 digit quick code.
    var quickNumber: Int { Catalog.quickNumbers[id] ?? 0 }

    var rating: Double? {
        reviews.isEmpty ? nil : Double(reviews.map(\.stars).reduce(0, +)) / Double(reviews.count)
    }

    func minutesLeft(fromPage page: Int) -> Int {
        Int((Double(max(0, pages - page)) * 1.5).rounded())
    }

    var readTime: String {
        let m = Int((Double(pages) * 1.5).rounded())
        return m < 60 ? "About \(m) min" : "About \(Int((Double(m) / 60).rounded())) hr read"
    }
}

/// One locker door on the kiosk. A book can sit in it and optionally be held for a reservation code.
struct Slot: Identifiable, Hashable {
    let id: String
    var bookID: String?
    var hold: String?
}

struct Reservation: Identifiable, Hashable {
    var id: String { code }
    let code: String
    let bookID: String
    let name: String
    var expires: Date
    var collected = false
    var pin: String? = nil
}

/// Everything the unlock screen needs to open a door.
struct CollectJob: Equatable, Identifiable {
    let id = UUID()
    let bookID: String
    let slotID: String
    let name: String?
    let code: String?
}

enum Route: Equatable {
    case attract, home, code, browse, help, staff
    case collect(CollectJob)
    case returnBook(String?)

    var key: String {
        switch self {
        case .attract: "attract"
        case .home: "home"
        case .code: "code"
        case .browse: "browse"
        case .help: "help"
        case .staff: "staff"
        case .collect(let j): "collect-\(j.id)"
        case .returnBook: "return"
        }
    }
}

/// Shown as a big friendly card when a scan can't be used.
struct KioskAlert: Identifiable, Equatable {
    let id = UUID()
    let symbol: String
    let title: String
    let message: String
    var bookID: String? = nil
}

/// What a QR code / barcode turned out to be.
enum ScanPayload: Equatable {
    case collect(code: String?, bookID: String?, name: String?, expires: Date?)
    case quick(String)
    case returnBook(String)

    /// Accepts the formats the phone app and pass generator produce:
    ///   betweenstops://collect?code=482913&book=redfern&name=Alex&exp=1760000000
    ///   betweenstops://return?book=salt
    ///   a bare 6 digit reservation code, a 4 digit quick code, or a book's barcode
    static func parse(_ raw: String, books: [Book]) -> ScanPayload? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URLComponents(string: s), url.scheme?.lowercased() == "betweenstops" {
            let q = Dictionary((url.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
            switch url.host?.lowercased() {
            case "collect":
                let exp = q["exp"].flatMap(Double.init).map { Date(timeIntervalSince1970: $0) }
                let name = q["name"].flatMap { $0.isEmpty ? nil : $0 }
                return .collect(code: q["code"], bookID: q["book"], name: name, expires: exp)
            case "return":
                if let b = q["book"] { return .returnBook(b) }
            default: break
            }
            return nil
        }
        if let b = books.first(where: { $0.barcode == s }) { return .returnBook(b.id) }
        let digits = s.filter(\.isNumber)
        let onlyDigits = digits.count == s.filter({ !$0.isWhitespace && $0 != "-" }).count
        if digits.count == 6, onlyDigits {
            return .collect(code: digits, bookID: nil, name: nil, expires: nil)
        }
        if digits.count == 4, onlyDigits { return .quick(digits) }
        return nil
    }
}

enum Catalog {
    static let stations = ["Penrith", "Blacktown", "Parramatta", "Granville", "Lidcombe", "Strathfield", "Burwood",
                           "Redfern", "Central", "Town Hall", "Wynyard", "North Sydney", "Chatswood", "Hornsby"]

    static let genres = ["All", "Short reads", "Fiction", "Non-fiction", "Poetry", "Kids"]

    /// Quick codes are this number followed by two random digits, so the kiosk can
    /// work out the book even when the phone booking hasn't synced yet.
    static let quickNumbers = ["redfern": 11, "tides": 12, "signal": 13, "pip": 14, "kettle": 15, "birds": 16,
                               "katoomba": 17, "quiet": 18, "bread": 19, "map": 20, "fig": 21, "orchard": 22, "salt": 23]

    static let tagOptions = ["Couldn't put it down", "Perfect for a short trip", "Made me laugh", "Read it in one go",
                             "Beautiful writing", "Slow start, worth it", "Great for kids", "Learned something"]

    static let books: [Book] = rawBooks.map { b in
        var b = b
        b.reviews = seedReviews[b.id] ?? []
        return b
    }

    private static let seedReviews: [String: [Review]] = [
        "redfern": [Review(stars: 5, text: "Read this between Lidcombe and Central and completely missed my stop.", tags: ["Couldn't put it down"], by: "Sam", when: "Yesterday"),
                    Review(stars: 4, text: "The ending on the platform got me.", tags: ["Beautiful writing"], by: "Priya", when: "Last week")],
        "tides": [Review(stars: 5, text: "Page 31 is the one. Read it twice.", tags: ["Perfect for a short trip"], by: "Priya", when: "Today")],
        "signal": [Review(stars: 4, text: "I'll never complain about delays again.", tags: ["Learned something"], by: "Marco", when: "Yesterday")],
        "pip": [Review(stars: 5, text: "My daughter asked for it three nights running.", tags: ["Great for kids"], by: "Tom", when: "Last week")],
        "kettle": [Review(stars: 4, text: "Laughed out loud on the quiet carriage. Sorry everyone.", tags: ["Made me laugh"], by: "Jess", when: "Today"),
                   Review(stars: 3, text: "", tags: ["Slow start, worth it"], by: "Ben", when: "2 weeks ago")],
        "katoomba": [Review(stars: 5, text: "Perfect foggy morning read.", tags: ["Read it in one go"], by: "Ana", when: "Yesterday")],
        "birds": [Review(stars: 4, text: "Spotted three currawongs at Strathfield thanks to this.", tags: ["Learned something"], by: "Alex", when: "2 days ago")],
    ]

    private static let rawBooks: [Book] = [
        Book(id: "redfern", title: "The Long Way to Redfern", author: "Mae Okafor", genre: "Fiction", pages: 312,
             c1: Color(hex: 0x2D5BA8), c2: Color(hex: 0xFFC72C), art: .sun,
             blurb: "Two sisters catch the same train every morning for a year without saying a word to each other. One of them is keeping a secret about the line.",
             trips: [Trip(what: "Left on this train at Strathfield", when: "Today, 6:58am"),
                     Trip(what: "Read from Hornsby to Central by Sam", when: "Yesterday"),
                     Trip(what: "Read from Epping to Chatswood", when: "3 days ago"),
                     Trip(what: "First shelved at Parramatta", when: "2 weeks ago")],
             note: ReaderNote(text: "Read this between Lidcombe and Central and completely missed my stop. Worth it.", by: "Sam"),
             km: 412, barcode: "9780000000017"),
        Book(id: "tides", title: "Small Tides", author: "Jun Park", genre: "Poetry", pages: 84,
             c1: Color(hex: 0x1F7A6B), c2: Color(hex: 0xF5E6C8), art: .waves,
             blurb: "Short poems about harbours, ferries and the people you only ever see on the morning commute.",
             trips: [Trip(what: "Left on this train by Priya", when: "Today, 7:12am"),
                     Trip(what: "Read on the T4 to Bondi Junction", when: "Last week")],
             note: ReaderNote(text: "Page 31 is the one. Read it twice.", by: "Priya"),
             km: 138, barcode: "9780000000024"),
        Book(id: "signal", title: "Signal Failure", author: "Dana Whitlock", genre: "Non-fiction", pages: 240,
             c1: Color(hex: 0xC2402A), c2: Color(hex: 0xFFF4E8), art: .stripes,
             blurb: "How a city keeps a thousand trains moving every day, and what happens in the control room when one of them stops.",
             trips: [Trip(what: "Left at Central by Marco", when: "Yesterday"),
                     Trip(what: "Read from Penrith to Blacktown", when: "4 days ago")],
             km: 265, barcode: "9780000000031"),
        Book(id: "pip", title: "Pip and the Night Train", author: "Hana Lowe", genre: "Kids", pages: 32,
             c1: Color(hex: 0xFFC72C), c2: Color(hex: 0x182033), art: .dots,
             blurb: "Pip is too excited to sleep, so the night train takes her on a tour of every sleeping town on the line.",
             trips: [Trip(what: "Left on this train by Tom", when: "Yesterday"),
                     Trip(what: "Read at Wynyard", when: "Last week")],
             km: 74, barcode: "9780000000048"),
        Book(id: "kettle", title: "Everything the Kettle Knows", author: "Rosa Mendes", genre: "Fiction", pages: 198,
             c1: Color(hex: 0xE8B4BC), c2: Color(hex: 0x5A2333), art: .circle,
             blurb: "A share house, five flatmates and one kettle that has heard every argument. Funny, warm and quick to get into.",
             trips: [Trip(what: "Left on this train by Jess", when: "Today, 6:40am")],
             km: 96, barcode: "9780000000055"),
        Book(id: "birds", title: "A Field Guide to City Birds", author: "Tom Ashby", genre: "Non-fiction", pages: 96,
             c1: Color(hex: 0x7FA650), c2: .white, art: .bird,
             blurb: "Spot the ibis, the noisy miner and the currawong from the train window. Pocket sized and great for short trips.",
             trips: [Trip(what: "Left on this train by Alex", when: "2 days ago"),
                     Trip(what: "Read at Lidcombe", when: "Last week")],
             km: 187, barcode: "9780000000062"),
        Book(id: "katoomba", title: "Last Stop, Katoomba", author: "Ellie Brandt", genre: "Fiction", pages: 288,
             c1: Color(hex: 0x3B2F6B), c2: Color(hex: 0xFFC72C), art: .moon,
             blurb: "A missed connection, a mountain fog and a stranger who seems to know exactly where the night is going.",
             trips: [Trip(what: "Left on this train by Ana", when: "Yesterday")],
             km: 54, barcode: "9780000000079"),
        Book(id: "quiet", title: "The Quiet Carriage", author: "Marcus Lee", genre: "Fiction", pages: 276,
             c1: Color(hex: 0x182033), c2: Color(hex: 0xE9ECF1), art: .lines,
             blurb: "Nobody is allowed to talk in the quiet carriage, which makes it the perfect place to plan something.",
             trips: [Trip(what: "Left on this train by Kim", when: "Today, 7:30am")],
             km: 211, barcode: "9780000000086"),
        Book(id: "bread", title: "Bread, Mostly", author: "Lena Fischer", genre: "Non-fiction", pages: 198,
             c1: Color(hex: 0xD9A441), c2: Color(hex: 0x3A2A12), art: .circle,
             blurb: "A baker writes about early starts, sourdough and the regulars who keep a small shop going.",
             trips: [Trip(what: "Left on this train by Ben", when: "Yesterday")],
             km: 129, barcode: "9780000000093"),
        // Not on this kiosk right now: these are out with readers or riding other trains.
        Book(id: "map", title: "How to Fold a Map", author: "Noor Haddad", genre: "Non-fiction", pages: 128,
             c1: Color(hex: 0xE9ECF1), c2: Color(hex: 0x2D5BA8), art: .lines,
             blurb: "Short essays about getting lost on purpose, from a writer who has never once folded a map the right way.",
             trips: [Trip(what: "Left on the 8:20 by Lily", when: "Yesterday")],
             km: 302, barcode: "9780000000109"),
        Book(id: "fig", title: "The Fig Tree Club", author: "Ari Coleman", genre: "Kids", pages: 64,
             c1: Color(hex: 0x4E8A3E), c2: Color(hex: 0xFFE7A3), art: .circle,
             blurb: "Four friends, one giant fig tree in the park, and a summer holiday that nobody wants to end.",
             trips: [Trip(what: "Left on the 8:20 by Joel", when: "2 days ago")],
             km: 88, barcode: "9780000000116"),
        Book(id: "orchard", title: "Orchard Hours", author: "Sofia Brennan", genre: "Fiction", pages: 240,
             c1: Color(hex: 0xB5523B), c2: Color(hex: 0xFBE3C9), art: .sun,
             blurb: "A woman goes back to her family orchard for one harvest and ends up staying for the whole year.",
             trips: [Trip(what: "Picked up by Alex", when: "Yesterday"),
                     Trip(what: "Left on this train by Mia", when: "Last week")],
             km: 176, barcode: "9780000000123"),
        Book(id: "salt", title: "Salt and Static", author: "Priya Raman", genre: "Fiction", pages: 224,
             c1: Color(hex: 0x5B8DB8), c2: .white, art: .waves,
             blurb: "A radio host on the late shift starts getting calls from someone who says they are on a train that stopped running years ago.",
             trips: [Trip(what: "Bought and shared by Alex", when: "Today")],
             km: 0, barcode: "9780000000130"),
    ]

    static func initialSlots() -> [Slot] {
        let layout: [String: String] = ["A1": "redfern", "A2": "tides", "A3": "signal", "A4": "pip",
                                        "B1": "kettle", "B3": "birds", "B4": "katoomba",
                                        "C1": "quiet", "C2": "bread"]
        let holds = ["A1": "482913", "A2": "105277"]
        return ["A", "B", "C"].flatMap { r in (1...4).map { c in
            let id = "\(r)\(c)"
            return Slot(id: id, bookID: layout[id], hold: holds[id])
        } }
    }

    static func initialReservations() -> [Reservation] {
        let now = Date()
        return [
            Reservation(code: "482913", bookID: "redfern", name: "Alex", expires: now.addingTimeInterval(25 * 60), pin: "1107"),
            Reservation(code: "105277", bookID: "tides", name: "Sam", expires: now.addingTimeInterval(40 * 60), pin: "1258"),
            Reservation(code: "660021", bookID: "signal", name: "Jess", expires: now.addingTimeInterval(-6 * 60), pin: "1330"),
            Reservation(code: "777314", bookID: "fig", name: "Kim", expires: now.addingTimeInterval(30 * 60), pin: "2144"),
            Reservation(code: "391540", bookID: "map", name: "Priya", expires: now.addingTimeInterval(20 * 60), collected: true, pin: "2016"),
        ]
    }

    /// Who has each book out right now, so a return can save a bookmark to the right account.
    static let initialLoans = ["salt": "Alex", "orchard": "Alex", "map": "Priya", "fig": "Joel"]

    /// Saved pages, per reader account. Alex left off part way through Redfern last time.
    static let initialBookmarks = ["Alex": ["redfern": 142]]

    /// Demo passes shown when the device has no camera (e.g. the Simulator), and as QR codes in staff mode.
    static let demoPasses: [(label: String, detail: String, payload: String)] = [
        ("Alex's pass", "Valid reservation", "betweenstops://collect?code=482913&book=redfern&name=Alex"),
        ("Sam's pass", "Valid reservation", "betweenstops://collect?code=105277&book=tides&name=Sam"),
        ("Jess's pass", "Expired", "betweenstops://collect?code=660021&book=signal&name=Jess"),
        ("Kim's pass", "Book is on another train", "betweenstops://collect?code=777314&book=fig&name=Kim"),
    ]
    static let demoReturns: [(label: String, payload: String)] = [
        ("Salt and Static", "betweenstops://return?book=salt"),
        ("Orchard Hours", "9780000000123"),
        ("How to Fold a Map", "betweenstops://return?book=map"),
    ]
}
