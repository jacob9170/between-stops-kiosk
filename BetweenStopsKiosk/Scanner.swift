import SwiftUI
import AVFoundation
import AudioToolbox

/// Live camera that reports QR codes and book barcodes.
struct CameraScanner: UIViewRepresentable {
    var active: Bool
    var onCode: (String) -> Void

    func makeUIView(context: Context) -> ScannerUIView {
        let v = ScannerUIView()
        v.onCode = onCode
        v.configure()
        return v
    }

    func updateUIView(_ v: ScannerUIView, context: Context) {
        v.onCode = onCode
        v.active = active
    }

    static func dismantleUIView(_ v: ScannerUIView, coordinator: ()) { v.stop() }
}

final class ScannerUIView: UIView, AVCaptureMetadataOutputObjectsDelegate {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    private var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "kiosk.camera")
    private var rotation: AVCaptureDevice.RotationCoordinator?
    private var rotationObs: NSKeyValueObservation?
    private var lastCode = ""
    private var lastTime = Date.distantPast

    var onCode: ((String) -> Void)?
    var active = true

    func configure() {
        preview.videoGravity = .resizeAspectFill
        preview.session = session
        backgroundColor = .black

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: setup()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                if ok { DispatchQueue.main.async { self.setup() } }
            }
        default: break
        }
    }

    private func setup() {
        // A kiosk faces the reader, so prefer the front camera.
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }
        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr, .ean13, .ean8, .code128].filter { output.availableMetadataObjectTypes.contains($0) }
        }
        session.commitConfiguration()

        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: preview)
        rotation = coordinator
        rotationObs = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak self] c, _ in
            let angle = c.videoRotationAngleForHorizonLevelPreview
            DispatchQueue.main.async { self?.preview.connection?.videoRotationAngle = angle }
        }

        queue.async { [session] in session.startRunning() }
    }

    func stop() {
        queue.async { [session] in session.stopRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard active, let code = (objects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
        // Ignore the same code being held in front of the camera.
        if code == lastCode, Date().timeIntervalSince(lastTime) < 4 { return }
        lastCode = code
        lastTime = Date()
        AudioServicesPlaySystemSound(1057)
        onCode?(code)
    }
}

/// The dark viewfinder panel. Shows the live camera when there is one,
/// otherwise a looping animation of a phone being held up.
struct Viewfinder: View {
    @Environment(KioskStore.self) private var store
    var expectingReturn = false
    @State private var sweep = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: 0x2B3550), Color(hex: 0x10151F)], center: .init(x: 0.5, y: 0.4),
                           startRadius: 10, endRadius: 420)

            if store.hasCamera {
                CameraScanner(active: store.alert == nil) { store.handleScan($0, expectingReturn: expectingReturn) }
                    .opacity(0.9)
            } else {
                PhoneHoldAnimation(returning: expectingReturn)
            }

            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height) * 0.62
                ZStack {
                    Corners()
                        .stroke(K.yellow, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .frame(width: side, height: side)
                        .scaleEffect(pulse ? 1.03 : 0.97)
                    Capsule()
                        .fill(K.yellow)
                        .frame(width: side * 0.9, height: 3)
                        .shadow(color: K.yellow, radius: 10)
                        .offset(y: sweep ? side * 0.42 : -side * 0.42)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            VStack {
                CameraStatus(returning: expectingReturn)
                    .padding(.top, 16)
                Spacer()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { sweep = true }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

/// Four rounded viewfinder corners.
struct Corners: Shape {
    func path(in r: CGRect) -> Path {
        let l = r.width * 0.18, c = r.width * 0.06
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + l)); p.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
        p.addQuadCurve(to: CGPoint(x: r.minX + c, y: r.minY), control: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX + l, y: r.minY))
        p.move(to: CGPoint(x: r.maxX - l, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + c), control: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY + l))
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - l)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        p.addQuadCurve(to: CGPoint(x: r.maxX - c, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX - l, y: r.maxY))
        p.move(to: CGPoint(x: r.minX + l, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - c), control: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY - l))
        return p
    }
}

/// Phone (or book) gliding up to the camera, for devices without one.
struct PhoneHoldAnimation: View {
    var returning = false
    @State private var t = false

    var body: some View {
        ZStack {
            if returning {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(hex: 0x5B8DB8))
                    .frame(width: 150, height: 210)
                    .overlay {
                        VStack(spacing: 2) {
                            HStack(spacing: 2) { ForEach(0..<18, id: \.self) { i in
                                Rectangle().fill(.black).frame(width: i % 3 == 0 ? 3 : 1.5, height: 40)
                            } }
                            Text("9780640017811").font(.system(size: 9).monospaced())
                        }
                        .padding(8).background(.white, in: RoundedRectangle(cornerRadius: 4))
                    }
            } else {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.white)
                    .frame(width: 150, height: 290)
                    .overlay {
                        VStack(spacing: 10) {
                            Text("Your pass").font(.system(size: 13, weight: .bold)).foregroundStyle(K.ink)
                            QRView(text: "betweenstops://collect?code=482913&book=redfern&name=Alex")
                                .frame(width: 104, height: 104)
                            Text("482 913").font(.system(size: 16, weight: .bold).monospacedDigit()).foregroundStyle(K.ink)
                        }
                    }
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color(hex: 0x1B1D22), lineWidth: 6))
            }
        }
        .rotationEffect(.degrees(t ? 0 : -8))
        .scaleEffect(t ? 0.82 : 0.6)
        .offset(y: t ? 0 : 260)
        .opacity(t ? 1 : 0.6)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { t = true }
        }
    }
}

/// Demo controls for the Simulator: tap a sample pass, or paste a QR image copied from the pass generator.
struct DemoScanTray: View {
    @Environment(KioskStore.self) private var store
    var returning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(store.hasCamera ? "Demo codes" : (returning ? "No camera here, try a demo book" : "No camera here, try a demo pass"),
                      systemImage: "wand.and.stars")
                    .font(.k(15, .bold))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Button {
                    if let img = UIPasteboard.general.image, let code = QR.decode(img) {
                        store.handleScan(code, expectingReturn: returning)
                    } else if let s = UIPasteboard.general.string {
                        store.handleScan(s, expectingReturn: returning)
                    } else {
                        store.showToast("Copy a QR image from the pass generator first")
                    }
                } label: {
                    Label("Paste QR", systemImage: "doc.on.clipboard").font(.k(15, .bold))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.white.opacity(0.12), in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(PressStyle())
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if returning {
                        ForEach(Catalog.demoReturns, id: \.payload) { d in
                            chip(d.label, "Book barcode", d.payload)
                        }
                    } else {
                        ForEach(Catalog.demoPasses, id: \.payload) { d in
                            chip(d.label, d.detail, d.payload)
                        }
                    }
                }
            }
        }
    }

    private func chip(_ title: String, _ detail: String, _ payload: String) -> some View {
        Button { store.handleScan(payload, expectingReturn: returning) } label: {
            HStack(spacing: 10) {
                Image(systemName: returning ? "barcode" : "qrcode").font(.system(size: 22, weight: .semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.k(16, .bold))
                    Text(detail).font(.k(13)).opacity(0.7)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressStyle())
    }
}

/// Tells the reader whether the kiosk is ready to scan, rather than leaving them guessing.
struct CameraStatus: View {
    @Environment(KioskStore.self) private var store
    var returning = false
    @State private var ping = false

    private var live: Bool {
        guard store.hasCamera else { return false }
        let auth = AVCaptureDevice.authorizationStatus(for: .video)
        return auth == .authorized || auth == .notDetermined
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(live ? Color(hex: 0x3DDC97) : K.t1)
                .frame(width: 10, height: 10)
                .overlay {
                    if live {
                        Circle().stroke(Color(hex: 0x3DDC97), lineWidth: 2)
                            .scaleEffect(ping ? 2.6 : 1).opacity(ping ? 0 : 0.8)
                    }
                }
            Text(live
                 ? (returning ? "Camera ready · scanning for a barcode" : "Camera ready · scanning for your QR code")
                 : (returning ? "Camera unavailable · pick your book or type the barcode" : "Camera unavailable · use a demo pass or type your code"))
                .font(.k(17, .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.black.opacity(0.55), in: Capsule())
        .onAppear { withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { ping = true } }
    }
}
