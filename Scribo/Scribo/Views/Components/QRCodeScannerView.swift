import SwiftUI
import AVFoundation
import UIKit

/// Full-screen camera QR reader; first payload is delivered once, then the session stops.
struct QRCodeScannerView: View {
    let onScan: (String) -> Void
    let onClose: () -> Void
    /// Camera denied or hardware not available — parent should show an alert.
    let onAccessFailed: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            QRScannerRepresentable(onScan: onScan, onAccessFailed: onAccessFailed)
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color.black.opacity(0.65), Color.black.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)

            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Circle().fill(Color.white.opacity(0.18)))
                }
                .buttonStyle(.plain)
                .padding(.leading, 20)
                .padding(.top, 12)
                Spacer()
            }
        }
    }
}

// MARK: - UIKit bridge

private struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onAccessFailed: () -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onScan = onScan
        vc.onAccessFailed = onAccessFailed
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    var onAccessFailed: (() -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didEmit = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configureSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startConfiguration()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.startConfiguration()
                    } else {
                        self?.onAccessFailed?()
                    }
                }
            }
        default:
            onAccessFailed?()
        }
    }

    private func startConfiguration() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            onAccessFailed?()
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            onAccessFailed?()
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]

        session.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didEmit,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let value = object.stringValue,
              !value.isEmpty else { return }
        didEmit = true
        session.stopRunning()
        onScan?(value)
    }
}
