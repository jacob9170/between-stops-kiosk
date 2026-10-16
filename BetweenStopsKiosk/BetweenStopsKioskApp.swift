import SwiftUI

@main
struct BetweenStopsKioskApp: App {
    @State private var store = KioskStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .persistentSystemOverlays(.hidden)
                .statusBarHidden()
                .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        }
    }
}

struct RootView: View {
    @Environment(KioskStore.self) private var store
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            K.bg.ignoresSafeArea()

            Group {
                switch store.route {
                case .attract: AttractView()
                case .home: HomeView()
                case .code: CodeEntryView()
                case .browse: BrowseView()
                case .help: HelpView()
                case .staff: StaffView()
                case .collect(let job): UnlockView(job: job)
                case .returnBook(let id): ReturnView(bookID: id)
                }
            }
            .id(store.route.key)
            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 1.03)),
                                    removal: .opacity.combined(with: .scale(scale: 0.98))))

            if let alert = store.alert {
                AlertCard(alert: alert)
                    .transition(.opacity)
                    .zIndex(10)
            }

            if store.showTour {
                TourView()
                    .transition(.opacity)
                    .zIndex(15)
            }

            if store.stillThere {
                StillThereView()
                    .transition(.opacity)
                    .zIndex(20)
            }

            if let toast = store.toast {
                VStack {
                    Text(toast)
                        .font(.k(18, .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22).padding(.vertical, 14)
                        .background(K.ink, in: Capsule())
                        .shadow(color: K.ink.opacity(0.3), radius: 16, y: 8)
                        .padding(.top, 104)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(30)
                .allowsHitTesting(false)
            }
        }
        .background(TouchWatcher { store.touch() })
        .onReceive(ticker) { _ in store.tick() }
    }
}

/// Friendly full-screen card for rejected scans.
struct AlertCard: View {
    @Environment(KioskStore.self) private var store
    let alert: KioskAlert
    @State private var shake: CGFloat = 0
    @State private var shown = false

    var body: some View {
        ZStack {
            K.ink.opacity(0.5).ignoresSafeArea()
                .onTapGesture { dismiss() }

            HStack(spacing: 36) {
                if let b = store.book(alert.bookID) {
                    BookCover(book: b, width: 170)
                        .rotationEffect(.degrees(-5))
                        .grayscale(0.4)
                }
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: alert.symbol)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(K.ink)
                        .frame(width: 76, height: 76)
                        .background(K.held, in: Circle())
                    Text(alert.title).font(.k(34, .bold)).foregroundStyle(K.ink)
                    Text(alert.message).font(.k(20)).foregroundStyle(K.muted).lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 14) {
                        Button("Try again") { dismiss() }
                            .buttonStyle(KioskButtonStyle(kind: .yellow, height: 64))
                        if alert.bookID != nil, store.route != .browse {
                            Button("Browse the shelf") { store.go(.browse) }
                                .buttonStyle(KioskButtonStyle(kind: .ghost, height: 64))
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: 520, alignment: .leading)
            }
            .padding(44)
            .background(K.bg, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
            .shadow(color: K.ink.opacity(0.3), radius: 40, y: 20)
            .modifier(Shake(animatableData: shake))
            .scaleEffect(shown ? 1 : 0.85)
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { shown = true }
            withAnimation(.linear(duration: 0.45).delay(0.2)) { shake = 1 }
        }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { store.alert = nil }
    }
}

struct StillThereView: View {
    @Environment(KioskStore.self) private var store
    @State private var start = Date()

    var body: some View {
        ZStack {
            K.ink.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 20) {
                CountdownRing(start: start, total: 12, size: 110, color: K.ink, track: K.grey)
                Text("Still there?").font(.k(36, .bold))
                Text("We'll head back to the start screen soon.").font(.k(20)).foregroundStyle(K.muted)
                Button("I'm still here") { store.touch() }
                    .buttonStyle(KioskButtonStyle(kind: .yellow))
                    .frame(width: 320)
                    .padding(.top, 6)
            }
            .padding(48)
            .background(K.bg, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
        }
        .onAppear { start = Date() }
    }
}

/// Resets the idle timer on any touch anywhere, without stealing touches from buttons or scroll views.
struct TouchWatcher: UIViewRepresentable {
    let onTouch: () -> Void

    func makeUIView(context: Context) -> WatcherView { WatcherView(onTouch: onTouch) }
    func updateUIView(_ v: WatcherView, context: Context) {}

    final class WatcherView: UIView {
        let onTouch: () -> Void
        private var installed = false

        init(onTouch: @escaping () -> Void) {
            self.onTouch = onTouch
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }
        required init?(coder: NSCoder) { fatalError() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window, !installed else { return }
            installed = true
            window.addGestureRecognizer(TouchSpy(onTouch: onTouch))
        }
    }

    /// Notices a touch then immediately fails, so it never competes with other gestures.
    final class TouchSpy: UIGestureRecognizer {
        let onTouch: () -> Void
        init(onTouch: @escaping () -> Void) {
            self.onTouch = onTouch
            super.init(target: nil, action: nil)
            cancelsTouchesInView = false
            delaysTouchesBegan = false
            delaysTouchesEnded = false
        }
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            onTouch()
            state = .failed
        }
        override func canPrevent(_ other: UIGestureRecognizer) -> Bool { false }
        override func canBePrevented(by other: UIGestureRecognizer) -> Bool { false }
    }
}
