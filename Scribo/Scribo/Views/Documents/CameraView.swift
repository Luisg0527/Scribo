import SwiftUI
import AVFoundation
import Photos

struct CameraView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    let onImageCaptured: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            return UIHostingController(rootView: CameraUnavailableView {
                presentationMode.wrappedValue.dismiss()
            })
        }

        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.cameraDevice = .rear
        picker.allowsEditing = false
        picker.showsCameraControls = true
        picker.delegate = context.coordinator

        // Wrap the picker so it fills edge-to-edge (avoids white/safe-area margins).
        return FullscreenContainerViewController(child: picker)
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let captured = info[.originalImage] as? UIImage
            picker.dismiss(animated: true) {
                Task { @MainActor in
                    if let image = captured {
                        SoundManager.shared.playShutterSound()
                        self.parent.onImageCaptured(image)
                    }
                    self.parent.presentationMode.wrappedValue.dismiss()
                }
                if let image = captured {
                    PHPhotoLibrary.requestAuthorization { status in
                        guard status == .authorized else { return }
                        PHPhotoLibrary.shared().performChanges({
                            let request = PHAssetCreationRequest.forAsset()
                            if let data = image.jpegData(compressionQuality: 0.8) {
                                request.addResource(with: .photo, data: data, options: nil)
                            }
                        }) { success, error in
                            if success {
                                print("📸 Image saved to photo library")
                            } else if let error {
                                print("❌ Failed to save to photo library: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
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

private struct CameraUnavailableView: View {
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 14) {
                Spacer()
                Image(systemName: "camera.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text("Camera not available")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text("This can happen in the iOS Simulator, or if camera access is restricted.\nTry running on a physical device.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Spacer()
                Button(action: onClose) {
                    Text("Close")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                }
            }
        }
    }
}