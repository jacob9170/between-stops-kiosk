import SwiftUI

/// The physical shelf: 3 rows of 4 glass doors, each holding one book.
struct LockerWall: View {
    @Environment(KioskStore.self) private var store
    var highlight: String? = nil
    var open: Set<String> = []
    var hideBookIn: String? = nil
    var cell: CGFloat = 120
    var namespace: Namespace.ID? = nil
    var onTap: ((Slot) -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            ForEach(["A", "B", "C"], id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(store.slots.filter { $0.id.hasPrefix(row) }) { slot in
                        let door = LockerDoor(slot: slot,
                                              book: slot.id == hideBookIn ? nil : store.book(slot.bookID),
                                              open: open.contains(slot.id),
                                              highlight: highlight == slot.id,
                                              w: cell, namespace: namespace)
                        if let onTap {
                            Button { onTap(slot) } label: { door }.buttonStyle(PressStyle())
                        } else {
                            door
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x2A3349), Color(hex: 0x1A2133)], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.35), radius: 30, y: 18)
        )
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
    }
}

struct LockerDoor: View {
    let slot: Slot
    let book: Book?
    let open: Bool
    let highlight: Bool
    let w: CGFloat
    var namespace: Namespace.ID?
    @State private var glow = false

    private var h: CGFloat { w * 1.32 }
    private var held: Bool { slot.hold != nil }

    var body: some View {
        ZStack {
            // the cavity behind the glass
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: 0x0B0F18))
                .overlay(alignment: .bottom) {
                    Rectangle().fill(.white.opacity(0.06)).frame(height: 6)
                }
            if let book {
                cover(book)
                    .padding(.bottom, 4)
            }
            if open {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(RadialGradient(colors: [K.yellow.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: w))
                    .allowsHitTesting(false)
            }

            // the glass door
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.20), .white.opacity(0.05), .white.opacity(0.12)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay {
                        // reflection streak
                        Rectangle().fill(.white.opacity(0.12)).frame(width: w * 0.12, height: h * 1.3)
                            .rotationEffect(.degrees(24)).offset(x: -w * 0.18, y: -h * 0.1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.25), lineWidth: 2)
                HStack {
                    Text(slot.id).font(.system(size: w * 0.12, weight: .bold).monospaced())
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(.black.opacity(0.35), in: Capsule())
                    Spacer()
                    if held {
                        Image(systemName: "lock.fill").font(.system(size: w * 0.1, weight: .bold))
                            .foregroundStyle(K.ink)
                            .padding(6).background(K.yellow, in: Circle())
                    }
                }
                .padding(8)
                // handle
                Capsule().fill(.white.opacity(0.5)).frame(width: 5, height: h * 0.22)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(.trailing, 8)
                // status light
                Circle()
                    .fill(open ? K.yellow : (book == nil ? Color.white.opacity(0.25) : (held ? K.t1 : Color(hex: 0x3DDC97))))
                    .frame(width: 8, height: 8)
                    .shadow(color: open ? K.yellow : .clear, radius: 6)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 8)
            }
            .frame(width: w, height: h)
            .rotation3DEffect(.degrees(open ? -112 : 0), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.45)
            .shadow(color: .black.opacity(open ? 0.4 : 0), radius: 10, x: -10)
            .animation(.spring(response: 0.8, dampingFraction: 0.62), value: open)
        }
        .frame(width: w, height: h)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(K.yellow, lineWidth: highlight ? 5 : 0)
                .shadow(color: K.yellow, radius: highlight ? (glow ? 22 : 8) : 0)
                .padding(-4)
                .animation(.easeInOut(duration: 0.15), value: highlight)
        }
        .zIndex(open ? 1 : 0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { glow = true }
        }
        .accessibilityElement()
        .accessibilityLabel("Door \(slot.id), \(book?.title ?? "empty")\(held ? ", held" : "")")
    }

    @ViewBuilder private func cover(_ b: Book) -> some View {
        let c = BookCover(book: b, width: w * 0.62, showText: w > 140)
        if let namespace {
            c.matchedGeometryEffect(id: "book-\(b.id)", in: namespace)
        } else {
            c
        }
    }
}
