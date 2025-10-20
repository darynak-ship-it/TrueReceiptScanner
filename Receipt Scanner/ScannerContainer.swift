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

struct ScannerOutput {
    let imageURL: URL
    let recognizedText: String
}

enum ScannerResult {
    case success(ScannerOutput)
    case failure(Error)
}

struct ScannerContainer: UIViewControllerRepresentable {
    typealias UIViewControllerType = UINavigationController

    let onComplete: (ScannerResult) -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let cameraController = VNDocumentCameraViewController()
        cameraController.delegate = context.coordinator
        cameraController.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Use Sample",
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.useSampleTapped)
        )
        let nav = UINavigationController(rootViewController: cameraController)
        nav.navigationBar.prefersLargeTitles = false
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onComplete: (ScannerResult) -> Void

        init(onComplete: @escaping (ScannerResult) -> Void) {
            self.onComplete = onComplete
        }

        @objc func useSampleTapped() {
            guard let image = SampleReceiptGenerator.generate() else {
                onComplete(.failure(NSError(domain: "Scanner", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to generate sample"])) )
                return
            }
            guard let url = FileStorage.save(image: image) else {
                onComplete(.failure(NSError(domain: "Scanner", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to save sample image"])) )
                return
            }
            OCRTextRecognizer.recognizeText(from: image) { [onComplete] text in
                onComplete(.success(ScannerOutput(imageURL: url, recognizedText: text ?? "")))
            }
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Use the first page (typical for receipts)
            guard scan.pageCount > 0 else {
                controller.dismiss(animated: true) { [onComplete] in
                    onComplete(.failure(NSError(domain: "Scanner", code: 0, userInfo: [NSLocalizedDescriptionKey: "No pages scanned"])) )
                }
                return
            }
            let image = scan.imageOfPage(at: 0)

            // Persist image efficiently
            guard let url = FileStorage.save(image: image) else {
                controller.dismiss(animated: true) { [onComplete] in
                    onComplete(.failure(NSError(domain: "Scanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to save image"])) )
                }
                return
            }

            // Perform OCR in background for quality
            OCRTextRecognizer.recognizeText(from: image) { [weak self] text in
                controller.dismiss(animated: true) {
                    let output = ScannerOutput(imageURL: url, recognizedText: text ?? "")
                    self?.onComplete(.success(output))
                }
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) { [onComplete] in
                onComplete(.failure(NSError(domain: "Scanner", code: 2, userInfo: [NSLocalizedDescriptionKey: "User cancelled"])) )
            }
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true) { [onComplete] in
                onComplete(.failure(error))
            }
        }
    }
}


