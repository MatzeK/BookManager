import SwiftUI
import AVFoundation
import Vision

struct ISBNScannerView: UIViewControllerRepresentable {
    @Binding var erkannteISBN: String?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> ISBNScannerViewController {
        let controller = ISBNScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: ISBNScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, ISBNScannerDelegate {
        let parent: ISBNScannerView

        init(_ parent: ISBNScannerView) {
            self.parent = parent
        }

        func didFindISBN(_ isbn: String) {
            parent.erkannteISBN = isbn
            parent.dismiss()
        }
    }
}

protocol ISBNScannerDelegate: AnyObject {
    func didFindISBN(_ isbn: String)
}

class ISBNScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: ISBNScannerDelegate?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var letzterScanZeitpunkt = Date.distantPast
    private let mindestZwischenScan: TimeInterval = 2.0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupOverlay()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        captureSession = session

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else { return }

        guard session.canAddInput(videoInput) else { return }
        session.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        guard session.canAddOutput(metadataOutput) else { return }
        session.addOutput(metadataOutput)

        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [.ean8, .ean13, .upce]

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
    }

    private func setupOverlay() {
        let overlayView = UIView()
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayView)

        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let hinweisLabel = UILabel()
        hinweisLabel.text = "Richte die Kamera auf den ISBN-Barcode"
        hinweisLabel.textColor = .white
        hinweisLabel.textAlignment = .center
        hinweisLabel.font = .systemFont(ofSize: 16, weight: .medium)
        hinweisLabel.numberOfLines = 2
        hinweisLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hinweisLabel)

        NSLayoutConstraint.activate([
            hinweisLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hinweisLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            hinweisLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            hinweisLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        let scanRahmen = UIView()
        scanRahmen.backgroundColor = .clear
        scanRahmen.layer.borderColor = UIColor.white.cgColor
        scanRahmen.layer.borderWidth = 2
        scanRahmen.layer.cornerRadius = 8
        scanRahmen.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scanRahmen)

        NSLayoutConstraint.activate([
            scanRahmen.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanRahmen.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            scanRahmen.widthAnchor.constraint(equalToConstant: 280),
            scanRahmen.heightAnchor.constraint(equalToConstant: 120)
        ])
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let isbn = readableObject.stringValue else { return }

        let jetzt = Date()
        guard jetzt.timeIntervalSince(letzterScanZeitpunkt) > mindestZwischenScan else { return }
        letzterScanZeitpunkt = jetzt

        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        delegate?.didFindISBN(isbn)
    }
}
