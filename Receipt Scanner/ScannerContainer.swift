//
//  ScannerContainer.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import SwiftUI
import Vision
import VisionKit
import UIKit
import AVFoundation

struct ScannerOutput {
    let imageURL: URL
    let recognizedText: String
}

enum ScannerResult {
    case success(ScannerOutput)
    case failure(Error)
}

struct ScannerContainer: UIViewControllerRepresentable {
    typealias UIViewControllerType = VNDocumentCameraViewController

    let onComplete: (ScannerResult) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        
        // iOS 18 compatibility: Ensure proper configuration
        if #available(iOS 18.0, *) {
            // Additional iOS 18 specific configurations if needed
        }
        
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onComplete: (ScannerResult) -> Void
        private var isProcessing = false

        init(onComplete: @escaping (ScannerResult) -> Void) {
            self.onComplete = onComplete
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Prevent multiple processing
            guard !isProcessing else { return }
            isProcessing = true
            
            // Use the first page (typical for receipts)
            guard scan.pageCount > 0 else {
                DispatchQueue.main.async { [weak self] in
                    controller.dismiss(animated: true) {
                        self?.onComplete(.failure(NSError(domain: "Scanner", code: 0, userInfo: [NSLocalizedDescriptionKey: "No pages scanned"])))
                    }
                }
                return
            }
            
            let image = scan.imageOfPage(at: 0)

            // Persist image efficiently on background queue
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                print("Starting image save process...")
                var finalURL: URL? = FileStorage.save(image: image)
                if finalURL == nil {
                    // Fallback: try saving to temporary directory so we can still proceed to edit screen
                    let timestamp = Int(Date().timeIntervalSince1970)
                    let uuid = UUID().uuidString.prefix(8)
                    let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("receipt_\(timestamp)_\(uuid).jpg")
                    if let data = image.jpegData(compressionQuality: 0.7) {
                        do {
                            try data.write(to: tmpURL, options: [.atomic])
                            finalURL = tmpURL
                            print("Fallback save succeeded at temporary path: \(tmpURL.path)")
                        } catch {
                            print("Fallback save to temporary directory failed: \(error)")
                        }
                    } else {
                        print("Failed to generate JPEG data for fallback save")
                    }
                }

                guard let url = finalURL else {
                    print("Failed to save image to disk (both documents and temp)")
                    DispatchQueue.main.async {
                        controller.dismiss(animated: true) {
                            self?.onComplete(.failure(NSError(domain: "Scanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not save scanned image."])))
                        }
                    }
                    return
                }
                
                print("Image saved successfully to: \(url.path)")
                
                // Verify the image was actually saved
                guard FileManager.default.fileExists(atPath: url.path) else {
                    print("Image file not found after saving at: \(url.path)")
                    DispatchQueue.main.async {
                        controller.dismiss(animated: true) {
                            self?.onComplete(.failure(NSError(domain: "Scanner", code: 3, userInfo: [NSLocalizedDescriptionKey: "Image file not found after saving."])))
                        }
                    }
                    return
                }

                print("Image file verified, starting OCR...")
                // Perform OCR in background for quality
                OCRTextRecognizer.recognizeText(from: image) { [weak self] text in
                    print("OCR completed with text: \(text?.prefix(50) ?? "nil")")
                    DispatchQueue.main.async {
                        controller.dismiss(animated: true) {
                            DispatchQueue.main.async {
                                let output = ScannerOutput(imageURL: url, recognizedText: text ?? "")
                                print("Scanner output created - calling completion")
                                self?.onComplete(.success(output))
                            }
                        }
                    }
                }
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            DispatchQueue.main.async { [weak self] in
                controller.dismiss(animated: true) {
                    self?.onComplete(.failure(NSError(domain: "Scanner", code: 2, userInfo: [NSLocalizedDescriptionKey: "User cancelled"])))
                }
            }
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            DispatchQueue.main.async { [weak self] in
                controller.dismiss(animated: true) {
                    self?.onComplete(.failure(error))
                }
            }
        }
    }
}


