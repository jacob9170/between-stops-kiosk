import SwiftUI

/// Hidden crew mode. Long-press the logo for 2 seconds on the home screen, PIN 2468.
struct StaffView: View {
    @Environment(KioskStore.self) private var store
    @State private var unlocked = false
    @State private var pin = ""
    @State private var shake: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            if unlocked { dashboard.transition(.opacity) } else { gate.transition(.opacity) }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: unlocked)
    }

    // MARK: PIN gate

    private var gate: some View {
        VStack(spacing: 26) {
            Image(systemName: "person.badge.key.fill").font(.system(size: 44)).foregroundStyle(K.ink)
                .frame(width: 100, height: 100).background(K.yellow, in: Circle())
            Text("Crew access").font(.k(36, .bold))
            HStack(spacing: 18) {
                ForEach(0..<4, id: \.self) { i in
                    Circle().fill(i < pin.count ? K.ink : K.line).frame(width: 22, height: 22)
                        .scaleEffect(i < pin.count ? 1.15 : 1)
                        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: pin.count)
                }
            }
            .modifier(Shake(animatableData: shake))
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(96), spacing: 14), count: 3), spacing: 14) {
                ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫"], id: \.self) { k in
                    if k.isEmpty { Color.clear.frame(height: 76) } else {
                        Button { press(k) } label: {
                            Text(k).font(.system(size: 30, weight: .bold)).foregroundStyle(K.ink)
                                .frame(width: 96, height: 76)
                                .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(PressStyle(scale: 0.92))
                    }
                }
            }
            Text("Demo PIN is 2468").font(.k(15)).foregroundStyle(K.muted)
        }
        .frame(maxHeight: .infinity)
    }

    private func press(_ k: String) {
        if k == "⌫" { if !pin.isEmpty { pin.removeLast() }; return }
        guard pin.count < 4 else { return }
        pin += k
        if pin.count == 4 {
            if pin == "2468" { unlocked = true }
            else {
                withAnimation(.linear(duration: 0.45)) { shake += 1 }
                Task { try? await Task.sleep(for: .seconds(0.45)); pin = "" }
            }
        }
    }

    // MARK: Dashboard

    private var dashboard: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Shelf status").font(.k(24, .bold))
                Text("Tap a door to open or close it.").font(.k(16)).foregroundStyle(K.muted)
                LockerWall(open: store.openDoors, cell: 112) { slot in
                    if store.openDoors.contains(slot.id) { store.openDoors.remove(slot.id) }
                    else { store.openDoors.insert(slot.id) }
                }
                HStack(spacing: 16) {
                    legend(Color(hex: 0x3DDC97), "Ready")
                    legend(K.t1, "Reserved")
                    legend(K.line, "Empty")
                    legend(K.yellow, "Open")
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        metric("\(store.booksOnShelf.count)/\(store.slots.count)", "doors filled")
                        metric("\(store.reservations.filter { !$0.collected && $0.expires > Date() }.count)", "active holds")
                        metric("\(store.borrowedToday)", "out today")
                    }
                    HStack(spacing: 12) {
                        metric("98%", "battery")
                        metric("Online", "connection")
                        metric("21°C", "cabinet")
                    }

                    Toggle(isOn: Binding(get: { store.showDemoPasses }, set: { store.showDemoPasses = $0 })) {
                        Text("Show demo passes on scan screens").font(.k(18, .bold))
                    }
                    .tint(K.blue)
                    .padding(18).background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    HStack(spacing: 12) {
                        Button("Open all") { store.openDoors = Set(store.slots.map(\.id)) }
                            .buttonStyle(KioskButtonStyle(kind: .ink, height: 60))
                        Button("Close all") { store.openDoors = [] }
                            .buttonStyle(KioskButtonStyle(kind: .ghost, height: 60))
                        Button("Reset demo") { store.resetDemo() }
                            .buttonStyle(KioskButtonStyle(kind: .danger, height: 60))
                    }

                    Text("Test passes").font(.k(22, .bold)).padding(.top, 6)
                    Text("Show these on another screen and hold them up to the kiosk camera.")
                        .font(.k(15)).foregroundStyle(K.muted)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        ForEach(Catalog.demoPasses, id: \.payload) { p in testCard(p.label, p.detail, p.payload) }
                        ForEach(Catalog.demoReturns, id: \.payload) { p in testCard(p.label, "Return", p.payload) }
                    }

                    Button("Exit crew mode") { store.openDoors = []; store.go(.home) }
                        .buttonStyle(KioskButtonStyle(kind: .yellow))
                }
                .padding(.bottom, 30)
            }
        }
        .padding(28)
    }

    private func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 6) { Circle().fill(c).frame(width: 10, height: 10); Text(t).font(.k(14)).foregroundStyle(K.muted) }
    }

    private func metric(_ big: String, _ small: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(big).font(.k(26, .bold))
            Text(small).font(.k(14)).foregroundStyle(K.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func testCard(_ title: String, _ detail: String, _ payload: String) -> some View {
        VStack(spacing: 8) {
            QRView(text: payload).frame(width: 120, height: 120)
            Text(title).font(.k(15, .bold)).lineLimit(1)
            Text(detail).font(.k(12)).foregroundStyle(K.muted).lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
