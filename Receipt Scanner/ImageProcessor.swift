//
//  ImageProcessor.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import UIKit
import CoreImage
import Vision

enum ImageProcessor {
    /// Processes an image to look like it was scanned - black & white, edge detection, perspective correction, enhanced contrast
    static func processScannedImage(from image: UIImage, completion: @escaping (UIImage?) -> Void) {
        guard let ciImage = CIImage(image: image) else {
            completion(nil)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            var processedImage = ciImage
            
            // Step 1: Detect document edges and apply perspective correction
            if let correctedImage = detectAndCorrectPerspective(in: processedImage) {
                processedImage = correctedImage
            }
            
            // Step 2: Convert to grayscale
            processedImage = convertToGrayscale(processedImage)
            
            // Step 3: Enhance contrast
            processedImage = enhanceContrast(processedImage)
            
            // Step 4: Apply adaptive thresholding for clean black and white
            processedImage = applyAdaptiveThreshold(processedImage)
            
            // Ensure the extent is valid and finite
            var extent = processedImage.extent
            if extent.isInfinite || extent.isNull {
                print("Warning: Invalid extent, using original image extent")
                extent = ciImage.extent
            }
            
            // Convert back to UIImage
            let context = CIContext(options: [.useSoftwareRenderer: false])
            guard let cgImage = context.createCGImage(processedImage, from: extent) else {
                print("Error: Failed to create CGImage from processed CIImage")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            let finalImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
            
            // Verify the image was created successfully
            guard finalImage.size.width > 0 && finalImage.size.height > 0 else {
                print("Error: Processed image has invalid size")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            print("Successfully processed image: \(finalImage.size)")
            DispatchQueue.main.async {
                completion(finalImage)
            }
        }
    }
    
    // MARK: - Document Detection and Perspective Correction
    
    private static func detectAndCorrectPerspective(in image: CIImage) -> CIImage? {
        // Downscale image for faster Vision processing (max 1024px on longest side)
        // This prevents freezing on large images like 4032x3024
        let maxDimension: CGFloat = 1024
        let originalExtent = image.extent
        let originalWidth = originalExtent.width
        let originalHeight = originalExtent.height
        
        let scale: CGFloat
        if originalWidth > originalHeight {
            scale = originalWidth > maxDimension ? maxDimension / originalWidth : 1.0
        } else {
            scale = originalHeight > maxDimension ? maxDimension / originalHeight : 1.0
        }
        
        let scaledWidth = originalWidth * scale
        let scaledHeight = originalHeight * scale
        
        // Create downscaled image for Vision detection
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            print("Failed to create CGImage for downscaling")
            return nil
        }
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: scaledWidth, height: scaledHeight))
        let downscaledUIImage = renderer.image { _ in
            UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: CGSize(width: scaledWidth, height: scaledHeight)))
        }
        
        guard let downscaledCGImage = downscaledUIImage.cgImage else {
            print("Failed to create downscaled CGImage")
            return nil
        }
        
        let downscaledCIImage = CIImage(cgImage: downscaledCGImage)
        
        print("Downscaled image from \(originalWidth) x \(originalHeight) to \(scaledWidth) x \(scaledHeight) for Vision detection")
        
        // Use a semaphore to wait for async Vision request completion
        // This is safe because we're already on a background thread
        let semaphore = DispatchSemaphore(value: 0)
        var result: CIImage? = nil
        
        let request = VNDetectRectanglesRequest { request, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("Error detecting rectangle: \(error.localizedDescription)")
                return
            }
            
            guard let results = request.results,
                  !results.isEmpty,
                  let rectangle = results.first as? VNRectangleObservation,
                  rectangle.confidence > 0.7 else {
                // No rectangle detected or low confidence, return original
                return
            }
            
            // Get the four corners of the detected rectangle (in normalized coordinates)
            let topLeft = rectangle.topLeft
            let topRight = rectangle.topRight
            let bottomRight = rectangle.bottomRight
            let bottomLeft = rectangle.bottomLeft
            
            // Scale coordinates back to original image size
            let inputQuad = [
                CIVector(x: topLeft.x * originalWidth, y: (1 - topLeft.y) * originalHeight),
                CIVector(x: topRight.x * originalWidth, y: (1 - topRight.y) * originalHeight),
                CIVector(x: bottomRight.x * originalWidth, y: (1 - bottomRight.y) * originalHeight),
                CIVector(x: bottomLeft.x * originalWidth, y: (1 - bottomLeft.y) * originalHeight)
            ]
            
            // Calculate document dimensions in original image coordinates
            let width = sqrt(pow(topRight.x - topLeft.x, 2) + pow(topRight.y - topLeft.y, 2)) * originalWidth
            let height = sqrt(pow(bottomLeft.x - topLeft.x, 2) + pow(bottomLeft.y - topLeft.y, 2)) * originalHeight
            
            // Apply perspective correction filter to original image
            guard let perspectiveFilter = CIFilter(name: "CIPerspectiveCorrection") else {
                return
            }
            
            perspectiveFilter.setValue(image, forKey: kCIInputImageKey)
            perspectiveFilter.setValue(inputQuad[0], forKey: "inputTopLeft")
            perspectiveFilter.setValue(inputQuad[1], forKey: "inputTopRight")
            perspectiveFilter.setValue(inputQuad[2], forKey: "inputBottomRight")
            perspectiveFilter.setValue(inputQuad[3], forKey: "inputBottomLeft")
            
            guard let correctedImage = perspectiveFilter.outputImage else {
                return
            }
            
            result = correctedImage.cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
        }
        
        request.minimumAspectRatio = 0.2
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.2
        request.minimumConfidence = 0.7
        request.usesCPUOnly = false
        
        let handler = VNImageRequestHandler(ciImage: downscaledCIImage, options: [:])
        
        do {
            try handler.perform([request])
            // Wait for completion with timeout (3 seconds max)
            if semaphore.wait(timeout: .now() + 3.0) == .timedOut {
                print("Rectangle detection timed out, skipping perspective correction")
                return nil
            }
            return result
        } catch {
            print("Error detecting rectangle: \(error)")
            return nil
        }
    }
    
    // MARK: - Image Filters
    
    private static func convertToGrayscale(_ image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIColorControls") else {
            // Fallback: use desaturate
            return image.applyingFilter("CIColorMonochrome", parameters: [
                kCIInputColorKey: CIColor.white,
                kCIInputIntensityKey: 1.0
            ])
        }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(0.0, forKey: kCIInputSaturationKey) // 0 = grayscale
        
        return filter.outputImage ?? image
    }
    
    private static func enhanceContrast(_ image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIColorControls") else {
            return image
        }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(1.2, forKey: kCIInputContrastKey) // Increase contrast
        filter.setValue(0.05, forKey: kCIInputBrightnessKey) // Slight brightness adjustment
        
        return filter.outputImage ?? image
    }
    
    private static func applyAdaptiveThreshold(_ image: CIImage) -> CIImage {
        // Use exposure and gamma adjustment for better black/white separation
        guard let exposureFilter = CIFilter(name: "CIExposureAdjust"),
              let gammaFilter = CIFilter(name: "CIGammaAdjust") else {
            return image
        }
        
        // First, adjust exposure for better contrast
        exposureFilter.setValue(image, forKey: kCIInputImageKey)
        exposureFilter.setValue(0.5, forKey: kCIInputEVKey)
        
        guard let exposedImage = exposureFilter.outputImage else {
            return image
        }
        
        // Then apply gamma correction for sharper blacks and whites
        gammaFilter.setValue(exposedImage, forKey: kCIInputImageKey)
        gammaFilter.setValue(0.8, forKey: "inputPower") // Lower values = more contrast
        
        guard let gammaImage = gammaFilter.outputImage else {
            return exposedImage
        }
        
        // Finally, apply a threshold-like effect using color controls
        guard let finalFilter = CIFilter(name: "CIColorControls") else {
            return gammaImage
        }
        
        finalFilter.setValue(gammaImage, forKey: kCIInputImageKey)
        finalFilter.setValue(1.5, forKey: kCIInputContrastKey) // High contrast for black/white
        
        return finalFilter.outputImage ?? gammaImage
    }
}

