import SwiftUI
import AVFoundation
import Photos

struct CameraView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    let onImageCaptured: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                // Play shutter sound
                SoundManager.shared.playShutterSound()
                
                // Save to photo library
                PHPhotoLibrary.requestAuthorization { status in
                    guard status == .authorized else {
                        print("❌ Photo library access denied")
                        return
                    }
                    
                    PHPhotoLibrary.shared().performChanges({
                        let request = PHAssetCreationRequest.forAsset()
                        if let data = image.jpegData(compressionQuality: 0.8) {
                            request.addResource(with: .photo, data: data, options: nil)
                        }
                    }) { success, error in
                        if success {
                            print("📸 Image saved to photo library")
                            // Fetch the created asset
                            let fetchOptions = PHFetchOptions()
                            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                            let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
                            if let asset = fetchResult.firstObject {
                                DispatchQueue.main.async {
                                    self.parent.onImageCaptured(image)
                                    self.parent.presentationMode.wrappedValue.dismiss()
                                }
                            }
            } else {
                            print("❌ Failed to save to photo library: \(error?.localizedDescription ?? "Unknown error")")
                        }
                    }
                }
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
} 