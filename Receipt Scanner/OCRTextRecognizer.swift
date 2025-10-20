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
            completion(nil)
            return
        }
        let request = VNRecognizeTextRequest { request, _ in
            let texts = (request.results as? [VNRecognizedTextObservation])?
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
            completion(texts)
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en_US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(nil)
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
        semaphore.wait()
        return result
    }
}


