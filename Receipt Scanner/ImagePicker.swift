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
            // Dismiss the picker
            picker.dismiss(animated: true)
            
            // Check if user cancelled (no selection)
            guard !results.isEmpty, let provider = results.first?.itemProvider else {
                DispatchQueue.main.async {
                    self.parent.onImageSelected?(nil)
                }
                return
            }
            
            // Load the image
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("Error loading image: \(error.localizedDescription)")
                            self.parent.onImageSelected?(nil)
                            return
                        }
                        
                        guard let selectedImage = image as? UIImage else {
                            print("Failed to cast image to UIImage")
                            self.parent.onImageSelected?(nil)
                            return
                        }
                        
                        print("Successfully loaded image from gallery: \(selectedImage.size)")
                        self.parent.selectedImage = selectedImage
                        self.parent.onImageSelected?(selectedImage)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    print("Provider cannot load UIImage")
                    self.parent.onImageSelected?(nil)
                }
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
