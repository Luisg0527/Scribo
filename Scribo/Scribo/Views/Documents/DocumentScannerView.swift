import SwiftUI
import UIKit
import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {
    let onScanComplete: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let scannerVC = VNDocumentCameraViewController()
        scannerVC.delegate = context.coordinator

        // Wrap so it renders edge-to-edge (avoids white/safe-area margins).
        return FullscreenContainerViewController(child: scannerVC)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanComplete: onScanComplete)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScanComplete: (UIImage) -> Void

        init(onScanComplete: @escaping (UIImage) -> Void) {
            self.onScanComplete = onScanComplete
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let image = scan.imageOfPage(at: 0)
            onScanComplete(image)
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Scanner error: \(error.localizedDescription)")
            controller.dismiss(animated: true)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }
    }
}

private final class FullscreenContainerViewController: UIViewController {
    private let childController: UIViewController

    init(child: UIViewController) {
        self.childController = child
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        view.backgroundColor = .black
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()

        addChild(childController)
        childController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(childController.view)
        NSLayoutConstraint.activate([
            childController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            childController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            childController.view.topAnchor.constraint(equalTo: view.topAnchor),
            childController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        childController.didMove(toParent: self)
    }
}
