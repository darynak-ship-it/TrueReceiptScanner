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
        private var hasProcessedSelection = false
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // Prevent duplicate processing
            guard !hasProcessedSelection else {
                print("ImagePicker: Already processed selection, ignoring duplicate callback")
                return
            }
            hasProcessedSelection = true
            
            // Dismiss the picker immediately
            picker.dismiss(animated: true, completion: nil)
            
            // Check if user cancelled (no selection)
            guard !results.isEmpty, let provider = results.first?.itemProvider else {
                // Call callback immediately after dismissal
                DispatchQueue.main.async {
                    self.parent.onImageSelected?(nil)
                }
                return
            }
            
            // Load the image on background queue to prevent blocking
            if provider.canLoadObject(ofClass: UIImage.self) {
                // Load image on background queue to prevent UI blocking
                DispatchQueue.global(qos: .userInitiated).async {
                    provider.loadObject(ofClass: UIImage.self) { image, error in
                        if let error = error {
                            print("Error loading image: \(error.localizedDescription)")
                            DispatchQueue.main.async {
                                self.parent.onImageSelected?(nil)
                            }
                            return
                        }
                        
                        guard let selectedImage = image as? UIImage else {
                            print("Failed to cast image to UIImage")
                            DispatchQueue.main.async {
                                self.parent.onImageSelected?(nil)
                            }
                            return
                        }
                        
                        print("Successfully loaded image from gallery: \(selectedImage.size)")
                        
                        // Downscale very large images immediately to prevent memory issues
                        let maxDimension: CGFloat = 2048
                        let imageSize = selectedImage.size
                        let finalImage: UIImage
                        
                        if max(imageSize.width, imageSize.height) > maxDimension {
                            let scale: CGFloat
                            if imageSize.width > imageSize.height {
                                scale = maxDimension / imageSize.width
                            } else {
                                scale = maxDimension / imageSize.height
                            }
                            
                            let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
                            let renderer = UIGraphicsImageRenderer(size: scaledSize)
                            finalImage = renderer.image { _ in
                                selectedImage.draw(in: CGRect(origin: .zero, size: scaledSize))
                            }
                            print("Downscaled image from \(imageSize) to \(scaledSize) for processing")
                        } else {
                            finalImage = selectedImage
                        }
                        
                        // Update on main thread immediately
                        DispatchQueue.main.async {
                            self.parent.selectedImage = finalImage
                            self.parent.onImageSelected?(finalImage)
                        }
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
