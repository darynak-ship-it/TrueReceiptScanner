//
//  ImagePicker.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import SwiftUI
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let onImageSelected: ((UIImage?) -> Void)?
    @Environment(\.dismiss) private var dismiss
    
    init(selectedImage: Binding<UIImage?>, onImageSelected: ((UIImage?) -> Void)? = nil) {
        self._selectedImage = selectedImage
        self.onImageSelected = onImageSelected
    }
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider else { 
                parent.onImageSelected?(nil)
                return 
            }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        let selectedImage = image as? UIImage
                        self.parent.selectedImage = selectedImage
                        self.parent.onImageSelected?(selectedImage)
                    }
                }
            } else {
                parent.onImageSelected?(nil)
            }
        }
    }
}

struct ImagePickerSheet: View {
    @Binding var selectedImage: UIImage?
    @State private var showImagePicker = false
    
    var body: some View {
        Button("Choose from Gallery") {
            showImagePicker = true
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
    }
}
