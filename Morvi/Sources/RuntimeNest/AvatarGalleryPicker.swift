import SwiftUI
import PhotosUI
import UIKit

struct AvatarGalleryPicker: UIViewControllerRepresentable {
    @Binding var selectedPortrait: UIImage?
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ viewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(owner: self)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let owner: AvatarGalleryPicker

        init(owner: AvatarGalleryPicker) {
            self.owner = owner
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                owner.isPresented = false
                return
            }
            provider.loadObject(ofClass: UIImage.self) { [owner] object, _ in
                DispatchQueue.main.async {
                    owner.selectedPortrait = object as? UIImage
                    owner.isPresented = false
                }
            }
        }
    }
}
