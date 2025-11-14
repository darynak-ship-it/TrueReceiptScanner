//
//  OCRTextRecognizer.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import Foundation
import Vision
import UIKit

enum OCRTextRecognizer {
    static func recognizeText(from image: UIImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage else {
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        // Downscale very large images for OCR to prevent freezing
        // OCR works well on 2048px images while being much faster than 4000px+
        let maxDimension: CGFloat = 2048
        let imageSize = image.size
        let imageForOCR: CGImage
        
        if max(imageSize.width, imageSize.height) > maxDimension {
            // Downscale the image
            let scale: CGFloat
            if imageSize.width > imageSize.height {
                scale = maxDimension / imageSize.width
            } else {
                scale = maxDimension / imageSize.height
            }
            
            let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let renderer = UIGraphicsImageRenderer(size: scaledSize)
            let downscaledImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: scaledSize))
            }
            
            if let downscaledCGImage = downscaledImage.cgImage {
                imageForOCR = downscaledCGImage
                print("Downscaled image from \(imageSize) to \(scaledSize) for OCR")
            } else {
                // Fallback to original if downscaling fails
                imageForOCR = cgImage
            }
        } else {
            imageForOCR = cgImage
        }
        
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("OCR Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            let texts = (request.results as? [VNRecognizedTextObservation])?
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
            
            DispatchQueue.main.async {
                completion(texts)
            }
        }
        
        // Configure for better accuracy
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        // Support multiple languages for better international receipt recognition
        request.recognitionLanguages = ["en_US", "de_DE", "fr_FR", "es_ES", "it_IT", "pt_PT", "nl_NL", "sv_SE", "da_DK", "no_NO", "fi_FI"]
        
        // iOS 18 compatibility improvements
        if #available(iOS 18.0, *) {
            // Additional iOS 18 specific configurations
            request.automaticallyDetectsLanguage = true
        }

        let handler = VNImageRequestHandler(cgImage: imageForOCR, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("OCR Handler Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }

    static func recognizeTextSync(from image: UIImage) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: String? = nil
        
        recognizeText(from: image) { text in
            result = text
            semaphore.signal()
        }
        
        // Add timeout to prevent hanging
        let timeout = DispatchTime.now() + .seconds(30)
        let waitResult = semaphore.wait(timeout: timeout)
        
        if waitResult == .timedOut {
            print("OCR recognition timed out")
            return nil
        }
        
        return result
    }
}


