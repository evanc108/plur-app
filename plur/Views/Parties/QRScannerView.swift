import SwiftUI
import AVFoundation

struct QRScannerView: UIViewControllerRepresentable {
    var onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onCodeScanned = onCodeScanned
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onCodeScanned: ((String) -> Void)?
        private let session = AVCaptureSession()
        private var hasScanned = false

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            setupCamera()
        }

        private func setupCamera() {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                showPlaceholder()
                return
            }

            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else {
                showPlaceholder()
                return
            }

            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.frame = view.bounds
            preview.videoGravity = .resizeAspectFill
            view.layer.addSublayer(preview)

            addOverlay()

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }

        private func addOverlay() {
            let cutoutSize: CGFloat = 240
            let overlayView = UIView(frame: view.bounds)
            overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(overlayView)

            let maskLayer = CAShapeLayer()
            let fullPath = UIBezierPath(rect: view.bounds)
            let cutoutOrigin = CGPoint(
                x: (view.bounds.width - cutoutSize) / 2,
                y: (view.bounds.height - cutoutSize) / 2
            )
            let cutoutRect = CGRect(origin: cutoutOrigin, size: CGSize(width: cutoutSize, height: cutoutSize))
            let cutoutPath = UIBezierPath(roundedRect: cutoutRect, cornerRadius: 16)
            fullPath.append(cutoutPath)
            maskLayer.path = fullPath.cgPath
            maskLayer.fillRule = .evenOdd
            overlayView.layer.mask = maskLayer

            let border = CAShapeLayer()
            border.path = cutoutPath.cgPath
            border.strokeColor = UIColor.white.cgColor
            border.fillColor = UIColor.clear.cgColor
            border.lineWidth = 3
            view.layer.addSublayer(border)
        }

        private func showPlaceholder() {
            let label = UILabel()
            label.text = "Camera not available\nin Simulator"
            label.numberOfLines = 0
            label.textColor = .white
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 18, weight: .medium)
            label.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ])
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard !hasScanned,
                  let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = object.stringValue else { return }
            hasScanned = true
            session.stopRunning()
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            onCodeScanned?(value)
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if session.isRunning { session.stopRunning() }
        }
    }
}
