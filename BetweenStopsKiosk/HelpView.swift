import SwiftUI

struct HelpView: View {
    @Environment(KioskStore.self) private var store
    @State private var shown = false
    @State private var calling = false
    @State private var reported: String?

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(alignment: .bottom) {
                        ScreenTitle(title: "How it works", subtitle: "A free library that lives on the train. Take a book, leave a book.")
                        Button { withAnimation(.spring) { store.showTour = true } } label: {
                            Label("Take the step-by-step tour", systemImage: "sparkles")
                        }
                        .buttonStyle(KioskButtonStyle(kind: .ink, height: 64))
                        .frame(width: 360)
                    }

                    HStack(spacing: 18) {
                        StepCard(n: 1, symbol: "iphone.gen3", title: "Reserve in the app",
                                 text: "Find a library train and reserve a book. We keep it for you for 30 minutes.", tint: K.blue)
                            .entrance(shown, delay: 0.0)
                        StepCard(n: 2, symbol: "qrcode.viewfinder", title: "Scan it here",
                                 text: "Hold your QR code up to the camera on the home screen.", tint: K.yellow)
                            .entrance(shown, delay: 0.1)
                        StepCard(n: 3, symbol: "book.fill", title: "Take it, read it",
                                 text: "Your door pops open. Keep it as long as you like.", tint: Color(hex: 0x1F7A6B))
                            .entrance(shown, delay: 0.2)
                        StepCard(n: 4, symbol: "arrow.uturn.down", title: "Leave it anywhere",
                                 text: "Return it to any Between Stops kiosk on any line.", tint: K.t1)
                            .entrance(shown, delay: 0.3)
                    }

                    HStack(alignment: .top, spacing: 18) {
                        // Accessibility
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Make it easier").font(.k(22, .bold))
                            Toggle(isOn: Binding(get: { store.textScale > 1 },
                                                 set: { on in withAnimation(.spring) { store.textScale = on ? 1.18 : 1 } })) {
                                Label("Larger text", systemImage: "textformat.size").font(.k(19, .bold))
                            }
                            .tint(K.blue)
                            Text("You can also tap Aa at the top of any screen. The keypad and buttons are reachable from a seat.")
                                .font(.k(15)).foregroundStyle(K.muted)
                        }
                        .padding(22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))

                        // Staff help
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Need a hand?").font(.k(22, .bold))
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { calling = true }
                                store.showToast("The train guard has been notified")
                            } label: {
                                Label(calling ? "Help is on the way" : "Call the guard", systemImage: calling ? "checkmark.circle.fill" : "bell.fill")
                                    .symbolEffect(.bounce, value: calling)
                            }
                            .buttonStyle(KioskButtonStyle(kind: calling ? .ink : .yellow, height: 64))
                            Text("Report a problem").font(.k(16, .bold)).foregroundStyle(K.muted).padding(.top, 4)
                            FlowLayout(spacing: 8) {
                                ForEach(["A door is stuck", "Book is damaged", "Scanner won't read", "Shelf is empty"], id: \.self) { p in
                                    Button {
                                        withAnimation(.spring(response: 0.3)) { reported = p }
                                        store.showToast("Thanks, we've let the crew know")
                                    } label: {
                                        Label(p, systemImage: reported == p ? "checkmark" : "exclamationmark.bubble")
                                            .font(.k(15, .bold))
                                            .foregroundStyle(reported == p ? .white : K.ink)
                                            .padding(.horizontal, 14).padding(.vertical, 10)
                                            .background(reported == p ? K.green : K.grey, in: Capsule())
                                    }
                                    .buttonStyle(PressStyle())
                                }
                            }
                        }
                        .padding(22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))

                        // App QR
                        VStack(spacing: 12) {
                            QRView(text: "https://rjschweitz.github.io/test").frame(width: 150, height: 150)
                            Text("Get the Between Stops app").font(.k(17, .bold)).multilineTextAlignment(.center)
                            Text("Plan a trip and reserve a book before you board.")
                                .font(.k(14)).foregroundStyle(K.muted).multilineTextAlignment(.center)
                        }
                        .padding(22)
                        .frame(width: 250)
                        .background(.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    }
                    .entrance(shown, delay: 0.35)

                    Text("Good to know: books are free, there are no late fees, and kids are welcome to borrow. Please keep food away from the shelf.")
                        .font(.k(16)).foregroundStyle(K.muted)
                }
                .padding(32)
            }
        }
        .onAppear { shown = true }
    }
}

struct StepCard: View {
    let n: Int
    let symbol: String
    let title: String
    let text: String
    let tint: Color
    @State private var bounce = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(tint == K.yellow ? K.ink : .white)
                    .symbolEffect(.bounce, value: bounce)
                    .frame(width: 76, height: 76)
                    .background(tint, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                Spacer()
                Text("\(n)").font(.k(44, .bold)).foregroundStyle(K.grey)
            }
            Text(title).font(.k(22, .bold))
            Text(text).font(.k(16)).foregroundStyle(K.muted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
        .background(.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .task {
            try? await Task.sleep(for: .seconds(Double(n) * 0.6))
            while !Task.isCancelled {
                bounce += 1
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }
}
