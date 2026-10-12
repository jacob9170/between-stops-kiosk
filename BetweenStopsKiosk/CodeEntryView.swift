import SwiftUI

/// Big keypad for readers whose phone screen won't scan (cracked, dim, flat battery but code written down...).
/// Takes either the 6 digit reservation code or the shorter 4 digit quick code from the app.
struct CodeEntryView: View {
    @Environment(KioskStore.self) private var store
    @State private var quick = false
    @State private var digits = ""
    @State private var shake: CGFloat = 0

    private var length: Int { quick ? 4 : 6 }

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            HStack(alignment: .center, spacing: 64) {
                VStack(alignment: .leading, spacing: 26) {
                    ScreenTitle(title: quick ? "Enter your quick code" : "Enter your code",
                                subtitle: quick ? "The 4 digit quick code from your booking in the app. Handy if you've jotted it down."
                                                : "It's the six digits under the QR code in the app, in Held for you.")

                    modePicker

                    HStack(spacing: 14) {
                        ForEach(0..<length, id: \.self) { i in
                            let ch = i < digits.count ? String(Array(digits)[i]) : ""
                            Text(ch)
                                .font(.system(size: 46, weight: .bold).monospacedDigit())
                                .foregroundStyle(K.ink)
                                .frame(width: quick ? 92 : 74, height: 96)
                                .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(i == digits.count ? (quick ? K.blue : K.ink) : K.line, lineWidth: i == digits.count ? 3 : 2))
                                .scaleEffect(ch.isEmpty ? 1 : 1.04)
                                .animation(.spring(response: 0.25, dampingFraction: 0.5), value: ch)
                            if i == 2 && !quick {
                                Capsule().fill(K.line).frame(width: 16, height: 5)
                            }
                        }
                    }
                    .modifier(Shake(animatableData: shake))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: quick)

                    Label(quick ? "Try 1107 for Alex's demo quick code" : "Try 482 913 for Alex's demo reservation",
                          systemImage: "lightbulb")
                        .font(.k(17)).foregroundStyle(K.muted)
                }

                VStack(spacing: 14) {
                    NumberPad(text: $digits, maxLength: length)
                    Button(quick ? "Unlock with quick code" : "Unlock my book") { submit() }
                        .buttonStyle(KioskButtonStyle(kind: .yellow, height: 80))
                        .disabled(digits.count < length)
                        .opacity(digits.count < length ? 0.45 : 1)
                        .animation(.easeInOut, value: digits.count)
                }
                .frame(width: 380)
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 56)
        }
    }

    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach([false, true], id: \.self) { q in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { quick = q; digits = "" }
                } label: {
                    Label(q ? "4 digit quick code" : "6 digit code", systemImage: q ? "bolt.fill" : "qrcode")
                        .font(.k(18, .bold))
                        .foregroundStyle(quick == q ? K.ink : K.muted)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background {
                            if quick == q {
                                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white)
                                    .shadow(color: K.ink.opacity(0.12), radius: 3, y: 1)
                            }
                        }
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(4)
        .background(K.grey, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .frame(maxWidth: 520)
    }

    private func submit() {
        guard digits.count == length else { return }
        let known = quick
            ? store.reservations.contains { $0.pin == digits } || store.books.contains { $0.quickNumber == Int(digits.prefix(2)) }
            : store.reservations.contains { $0.code == digits }
        if !known {
            withAnimation(.linear(duration: 0.45)) { shake += 1 }
        }
        store.handleScan(digits)
        if !known { digits = "" }
    }
}
