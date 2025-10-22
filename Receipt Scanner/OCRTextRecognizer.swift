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
        request.recognitionLanguages = ["en_US"]
        
        // iOS 18 compatibility improvements
        if #available(iOS 18.0, *) {
            // Additional iOS 18 specific configurations
            request.automaticallyDetectsLanguage = true
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
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


