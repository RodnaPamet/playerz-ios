import SwiftUI
import UIKit

/// The camera, for a photo of a certificate (#20). SwiftUI has no camera view
/// of its own, so this wraps UIKit's picker: JPEG at 0.8, which keeps a
/// phone's photo of a page well under the server's 5 MB.
struct CameraPicker: UIViewControllerRepresentable {
    let taken: (Data?) -> Void

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(taken: taken) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let taken: (Data?) -> Void

        init(taken: @escaping (Data?) -> Void) {
            self.taken = taken
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            taken(image?.jpegData(compressionQuality: 0.8))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            taken(nil)
        }
    }
}
