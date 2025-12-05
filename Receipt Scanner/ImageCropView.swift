//
//  ImageCropView.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import SwiftUI
import UIKit
import Vision

struct ImageCropView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void
    
    @State private var cropRect: CGRect = .zero
    @State private var imageDisplaySize: CGSize = .zero
    @State private var imageDisplayOrigin: CGPoint = .zero
    @State private var isDetecting: Bool = true
    @State private var rotationAngle: CGFloat = 0 // Rotation in degrees (0, 90, 180, 270)
    @State private var cachedRotatedImage: UIImage?
    
    private var rotatedImage: UIImage {
        // Use cached image if rotation hasn't changed, otherwise compute on background
        if rotationAngle == 0 {
            return image
        }
        
        // Return cached image if available and rotation matches
        if let cached = cachedRotatedImage {
            return cached
        }
        
        // For initial load, return original image and rotate in background
        return image
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    // Image display (non-interactive, crop overlay handles interaction)
                    Image(uiImage: rotatedImage)
                        .resizable()
                        .scaledToFit()
                        .onAppear {
                            calculateImageDisplaySize(in: geometry.size)
                        }
                        .onChange(of: geometry.size) { _ in
                            calculateImageDisplaySize(in: geometry.size)
                        }
                        .onChange(of: rotationAngle) { newAngle in
                            // Rotate image on background thread to prevent blocking
                            if newAngle != 0 {
                                DispatchQueue.global(qos: .userInitiated).async {
                                    let rotated = self.image.rotated(by: newAngle)
                                    DispatchQueue.main.async {
                                        self.cachedRotatedImage = rotated
                                        // Recalculate display size when rotated
                                        self.calculateImageDisplaySize(in: geometry.size)
                                        // Reset crop rect to default after rotation
                                        self.setupDefaultCropRect()
                                    }
                                }
                            } else {
                                cachedRotatedImage = nil
                                calculateImageDisplaySize(in: geometry.size)
                                setupDefaultCropRect()
                            }
                        }
                    
                    // Crop overlay
                    if !isDetecting {
                        CropOverlayView(
                            cropRect: $cropRect,
                            imageSize: (cachedRotatedImage ?? image).size,
                            imageDisplaySize: imageDisplaySize,
                            imageDisplayOrigin: imageDisplayOrigin,
                            containerSize: geometry.size
                        )
                    } else {
                        // Loading indicator while detecting
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Detecting receipt...")
                                .foregroundColor(.white)
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Select Receipt Area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(.accentColor)
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Rotate left button
                    Button(action: {
                        rotationAngle = (rotationAngle - 90).truncatingRemainder(dividingBy: 360)
                        if rotationAngle < 0 {
                            rotationAngle += 360
                        }
                    }) {
                        Image(systemName: "rotate.left")
                            .foregroundColor(.accentColor)
                    }
                    
                    // Rotate right button
                    Button(action: {
                        rotationAngle = (rotationAngle + 90).truncatingRemainder(dividingBy: 360)
                    }) {
                        Image(systemName: "rotate.right")
                            .foregroundColor(.accentColor)
                    }
                    
                    // Done button
                    Button("Done") {
                        cropImage()
                    }
                    .foregroundColor(.accentColor)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                // Initialize crop rect if not set
                if cropRect == .zero {
                    setupDefaultCropRect()
                }
                detectReceiptArea()
            }
        }
    }
    
    private func calculateImageDisplaySize(in containerSize: CGSize) {
        // Use rotated image size for display calculations
        // For initial calculation, use original image size (rotation will update later)
        let currentImage = cachedRotatedImage ?? image
        let imageAspect = currentImage.size.width / currentImage.size.height
        let containerAspect = containerSize.width / containerSize.height
        
        if imageAspect > containerAspect {
            // Image is wider
            imageDisplaySize = CGSize(width: containerSize.width, height: containerSize.width / imageAspect)
            imageDisplayOrigin = CGPoint(x: 0, y: (containerSize.height - imageDisplaySize.height) / 2)
        } else {
            // Image is taller
            imageDisplaySize = CGSize(width: containerSize.height * imageAspect, height: containerSize.height)
            imageDisplayOrigin = CGPoint(x: (containerSize.width - imageDisplaySize.width) / 2, y: 0)
        }
    }
    
    private func detectReceiptArea() {
        guard let cgImage = image.cgImage else {
            DispatchQueue.main.async {
                self.setupDefaultCropRect()
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isDetecting = true
        }
        
        var requestCompleted = false
        let lock = NSLock()
        
        // Store original size for coordinate conversion
        let originalSize = image.size
        
        // Downscale image for faster Vision processing (max 1024px on longest side)
        // This prevents freezing on large images like 4032x3024
        let maxDimension: CGFloat = 1024
        
        // In SwiftUI, structs don't create retain cycles, so weak references aren't needed
        DispatchQueue.global(qos: .userInitiated).async {
            
            // Calculate scale and create downscaled image on background thread
            let scale: CGFloat
            if originalSize.width > originalSize.height {
                scale = originalSize.width > maxDimension ? maxDimension / originalSize.width : 1.0
            } else {
                scale = originalSize.height > maxDimension ? maxDimension / originalSize.height : 1.0
            }
            
            let scaledSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)
            
            // Create downscaled image for Vision processing
            guard let downscaledCGImage = self.createDownscaledImage(cgImage: cgImage, targetSize: scaledSize) else {
                DispatchQueue.main.async {
                    self.isDetecting = false
                    print("Failed to downscale image, using default crop")
                    self.setupDefaultCropRect()
                }
                return
            }
            
            print("Downscaled image from \(originalSize) to \(scaledSize) for Vision detection")
            
            // Capture originalSize for use in closure
            let capturedOriginalSize = originalSize
            
            let request = VNDetectRectanglesRequest { request, error in
                lock.lock()
                defer { lock.unlock() }
                
                guard !requestCompleted else { return }
                requestCompleted = true
                
                DispatchQueue.main.async {
                    self.isDetecting = false
                    
                    if let error = error {
                        print("Error detecting receipt: \(error.localizedDescription)")
                        self.setupDefaultCropRect()
                        return
                    }
                    
                    guard let results = request.results as? [VNRectangleObservation],
                          let rectangle = results.first,
                          rectangle.confidence > 0.6 else {
                        print("No receipt detected, using default crop")
                        self.setupDefaultCropRect()
                        return
                    }
                    
                    // Convert Vision coordinates to original image coordinates
                    // Vision uses normalized coordinates (0-1) with origin at bottom-left
                    // UIImage uses origin at top-left
                    // Scale coordinates back to original image size
                    let imageWidth = capturedOriginalSize.width
                    let imageHeight = capturedOriginalSize.height
                    
                    // Convert normalized coordinates to scaled image coordinates, then scale up
                    let topLeft = CGPoint(
                        x: rectangle.topLeft.x * imageWidth,
                        y: (1 - rectangle.topLeft.y) * imageHeight
                    )
                    let topRight = CGPoint(
                        x: rectangle.topRight.x * imageWidth,
                        y: (1 - rectangle.topRight.y) * imageHeight
                    )
                    let bottomLeft = CGPoint(
                        x: rectangle.bottomLeft.x * imageWidth,
                        y: (1 - rectangle.bottomLeft.y) * imageHeight
                    )
                    let bottomRight = CGPoint(
                        x: rectangle.bottomRight.x * imageWidth,
                        y: (1 - rectangle.bottomRight.y) * imageHeight
                    )
                    
                    // Calculate bounding rect
                    let minX = min(topLeft.x, topRight.x, bottomLeft.x, bottomRight.x)
                    let maxX = max(topLeft.x, topRight.x, bottomLeft.x, bottomRight.x)
                    let minY = min(topLeft.y, topRight.y, bottomLeft.y, bottomRight.y)
                    let maxY = max(topLeft.y, topRight.y, bottomLeft.y, bottomRight.y)
                    
                    // Add small padding (5% on each side)
                    let paddingX = (maxX - minX) * 0.05
                    let paddingY = (maxY - minY) * 0.05
                    
                    self.cropRect = CGRect(
                        x: max(0, minX - paddingX),
                        y: max(0, minY - paddingY),
                        width: min(imageWidth - (minX - paddingX), maxX - minX + (paddingX * 2)),
                        height: min(imageHeight - (minY - paddingY), maxY - minY + (paddingY * 2))
                    )
                    
                    print("Detected receipt area: \(self.cropRect) with confidence: \(rectangle.confidence)")
                }
            }
            
            request.minimumAspectRatio = 0.2
            request.maximumAspectRatio = 1.0
            request.minimumSize = 0.2
            request.minimumConfidence = 0.6
            
            let handler = VNImageRequestHandler(cgImage: downscaledCGImage, options: [:])
            
            // Add timeout to prevent hanging
            let timeoutWorkItem = DispatchWorkItem {
                lock.lock()
                defer { lock.unlock() }
                
                guard !requestCompleted else { return }
                requestCompleted = true
                
                DispatchQueue.main.async {
                    self.isDetecting = false
                    print("Receipt detection timed out, using default crop")
                    self.setupDefaultCropRect()
                }
            }
            
            // Schedule timeout (2.5 seconds max for detection - reduced since we're using smaller image)
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2.5, execute: timeoutWorkItem)
            
            do {
                try handler.perform([request])
            } catch {
                lock.lock()
                defer { lock.unlock() }
                
                guard !requestCompleted else { return }
                requestCompleted = true
                timeoutWorkItem.cancel()
                
                DispatchQueue.main.async {
                    self.isDetecting = false
                    print("Failed to detect receipt: \(error)")
                    self.setupDefaultCropRect()
                }
            }
        }
    }
    
    private func createDownscaledImage(cgImage: CGImage, targetSize: CGSize) -> CGImage? {
        // Use UIGraphicsImageRenderer for efficient downscaling
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let downscaledImage = renderer.image { _ in
            UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return downscaledImage.cgImage
    }
    
    private func setupDefaultCropRect() {
        // Set initial crop rect to center 80% of rotated image
        let currentImage = cachedRotatedImage ?? image
        let cropWidth = currentImage.size.width * 0.8
        let cropHeight = currentImage.size.height * 0.8
        let cropX = (currentImage.size.width - cropWidth) / 2
        let cropY = (currentImage.size.height - cropHeight) / 2
        
        cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
    }
    
    private func cropImage() {
        // Use the rotated image for cropping
        let currentImage = cachedRotatedImage ?? image
        guard let cgImage = currentImage.cgImage else {
            print("Failed to get CGImage")
            onCancel()
            return
        }
        
        // Ensure crop rect is within image bounds
        let boundedRect = cropRect.intersection(CGRect(origin: .zero, size: currentImage.size))
        
        guard boundedRect.width > 0 && boundedRect.height > 0 else {
            print("Invalid crop rect")
            onCancel()
            return
        }
        
        guard let croppedCGImage = cgImage.cropping(to: boundedRect) else {
            print("Failed to crop image")
            onCancel()
            return
        }
        
        let croppedImage = UIImage(cgImage: croppedCGImage, scale: currentImage.scale, orientation: currentImage.imageOrientation)
        print("Successfully cropped and rotated image: \(croppedImage.size)")
        onCrop(croppedImage)
    }
}

struct CropOverlayView: View {
    @Binding var cropRect: CGRect
    let imageSize: CGSize
    let imageDisplaySize: CGSize
    let imageDisplayOrigin: CGPoint
    let containerSize: CGSize
    
    @State private var dragStart: CGPoint = .zero
    @State private var isDragging: Bool = false
    @State private var resizeHandle: CropResizeHandle? = nil
    @State private var lastCropRect: CGRect = .zero
    @State private var accumulatedTranslation: CGSize = .zero
    
    enum CropResizeHandle {
        case topLeft, topRight, bottomLeft, bottomRight, top, bottom, left, right, center
    }
    
    var body: some View {
        GeometryReader { geometry in
            let displayRect = calculateDisplayRect()
            
            ZStack {
                // Dark overlay outside crop area
                Color.black.opacity(0.6)
                    .mask(
                        ZStack {
                            Rectangle()
                            RoundedRectangle(cornerRadius: 8)
                                .frame(width: displayRect.width, height: displayRect.height)
                                .position(x: displayRect.midX, y: displayRect.midY)
                                .blendMode(.destinationOut)
                        }
                    )
                
                // Crop rectangle border
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white, lineWidth: 2)
                    .frame(width: displayRect.width, height: displayRect.height)
                    .position(x: displayRect.midX, y: displayRect.midY)
                
                // Corner handles
                ForEach([CropCorner.topLeft, .topRight, .bottomLeft, .bottomRight], id: \.self) { corner in
                    CropHandleView(corner: corner)
                        .position(cornerPosition(corner, in: displayRect))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            dragStart = value.startLocation
                            resizeHandle = determineResizeHandle(at: value.startLocation, in: displayRect)
                            lastCropRect = cropRect
                            accumulatedTranslation = .zero
                        }
                        
                        // Accumulate translation with damping to reduce sensitivity
                        let damping: CGFloat = 0.7
                        accumulatedTranslation = CGSize(
                            width: accumulatedTranslation.width + (value.translation.width - accumulatedTranslation.width) * damping,
                            height: accumulatedTranslation.height + (value.translation.height - accumulatedTranslation.height) * damping
                        )
                        
                        if let handle = resizeHandle {
                            resizeCropRect(handle: handle, translation: accumulatedTranslation, start: dragStart, displayRect: displayRect)
                        } else {
                            // Move the entire crop rect
                            moveCropRect(translation: accumulatedTranslation, displayRect: displayRect)
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        resizeHandle = nil
                        accumulatedTranslation = .zero
                    }
            )
        }
    }
    
    private func calculateDisplayRect() -> CGRect {
        // Convert crop rect from image coordinates to display coordinates
        let scaleX = imageDisplaySize.width / imageSize.width
        let scaleY = imageDisplaySize.height / imageSize.height
        
        return CGRect(
            x: imageDisplayOrigin.x + cropRect.origin.x * scaleX,
            y: imageDisplayOrigin.y + cropRect.origin.y * scaleY,
            width: cropRect.width * scaleX,
            height: cropRect.height * scaleY
        )
    }
    
    private func cornerPosition(_ corner: CropCorner, in rect: CGRect) -> CGPoint {
        switch corner {
        case .topLeft:
            return CGPoint(x: rect.minX, y: rect.minY)
        case .topRight:
            return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft:
            return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight:
            return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }
    
    private func determineResizeHandle(at point: CGPoint, in rect: CGRect) -> CropResizeHandle? {
        let handleSize: CGFloat = 44
        
        // Check corners
        let corners: [(CropCorner, CGPoint, CropResizeHandle)] = [
            (.topLeft, CGPoint(x: rect.minX, y: rect.minY), .topLeft),
            (.topRight, CGPoint(x: rect.maxX, y: rect.minY), .topRight),
            (.bottomLeft, CGPoint(x: rect.minX, y: rect.maxY), .bottomLeft),
            (.bottomRight, CGPoint(x: rect.maxX, y: rect.maxY), .bottomRight)
        ]
        
        for (_, cornerPoint, handle) in corners {
            if abs(point.x - cornerPoint.x) < handleSize && abs(point.y - cornerPoint.y) < handleSize {
                return handle
            }
        }
        
        // Check edges
        if abs(point.y - rect.minY) < handleSize && point.x >= rect.minX && point.x <= rect.maxX {
            return .top
        }
        if abs(point.y - rect.maxY) < handleSize && point.x >= rect.minX && point.x <= rect.maxX {
            return .bottom
        }
        if abs(point.x - rect.minX) < handleSize && point.y >= rect.minY && point.y <= rect.maxY {
            return .left
        }
        if abs(point.x - rect.maxX) < handleSize && point.y >= rect.minY && point.y <= rect.maxY {
            return .right
        }
        
        // Check if inside rect (move)
        if rect.contains(point) {
            return .center
        }
        
        return nil
    }
    
    private func resizeCropRect(handle: CropResizeHandle, translation: CGSize, start: CGPoint, displayRect: CGRect) {
        // Convert display coordinates to image coordinates
        // Ensure we have valid display size to avoid division by zero
        guard imageDisplaySize.width > 0 && imageDisplaySize.height > 0 else {
            print("Invalid imageDisplaySize, skipping resize")
            return
        }
        
        let scaleX = imageSize.width / imageDisplaySize.width
        let scaleY = imageSize.height / imageDisplaySize.height
        
        // Use last crop rect as base to prevent cumulative errors
        // Initialize lastCropRect if it's zero (first time)
        var baseRect = lastCropRect
        if baseRect == .zero {
            baseRect = cropRect
            lastCropRect = cropRect
        }
        
        var newRect = baseRect
        let deltaX = translation.width * scaleX
        let deltaY = translation.height * scaleY
        
        switch handle {
        case .topLeft:
            newRect.origin.x += deltaX
            newRect.origin.y += deltaY
            newRect.size.width -= deltaX
            newRect.size.height -= deltaY
        case .topRight:
            newRect.origin.y += deltaY
            newRect.size.width += deltaX
            newRect.size.height -= deltaY
        case .bottomLeft:
            newRect.origin.x += deltaX
            newRect.size.width -= deltaX
            newRect.size.height += deltaY
        case .bottomRight:
            newRect.size.width += deltaX
            newRect.size.height += deltaY
        case .top:
            newRect.origin.y += deltaY
            newRect.size.height -= deltaY
        case .bottom:
            newRect.size.height += deltaY
        case .left:
            newRect.origin.x += deltaX
            newRect.size.width -= deltaX
        case .right:
            newRect.size.width += deltaX
        case .center:
            newRect.origin.x += deltaX
            newRect.origin.y += deltaY
        }
        
        // Ensure minimum size and bounds
        newRect.size.width = max(50, newRect.size.width)
        newRect.size.height = max(50, newRect.size.height)
        newRect.origin.x = max(0, min(newRect.origin.x, imageSize.width - newRect.size.width))
        newRect.origin.y = max(0, min(newRect.origin.y, imageSize.height - newRect.size.height))
        
        cropRect = newRect
    }
    
    private func moveCropRect(translation: CGSize, displayRect: CGRect) {
        // Ensure we have valid display size to avoid division by zero
        guard imageDisplaySize.width > 0 && imageDisplaySize.height > 0 else {
            print("Invalid imageDisplaySize, skipping move")
            return
        }
        
        let scaleX = imageSize.width / imageDisplaySize.width
        let scaleY = imageSize.height / imageDisplaySize.height
        
        // Initialize lastCropRect if it's zero (first time)
        var baseRect = lastCropRect
        if baseRect == .zero {
            baseRect = cropRect
            lastCropRect = cropRect
        }
        
        var newRect = baseRect
        newRect.origin.x += translation.width * scaleX
        newRect.origin.y += translation.height * scaleY
        
        // Keep within bounds
        newRect.origin.x = max(0, min(newRect.origin.x, imageSize.width - newRect.size.width))
        newRect.origin.y = max(0, min(newRect.origin.y, imageSize.height - newRect.size.height))
        
        cropRect = newRect
    }
}

enum CropCorner {
    case topLeft, topRight, bottomLeft, bottomRight
}

struct CropHandleView: View {
    let corner: CropCorner
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 24, height: 24)
            .overlay(
                Circle()
                    .stroke(Color.accentColor, lineWidth: 2)
            )
            .shadow(radius: 2)
    }
}

// MARK: - UIImage Rotation Extension

extension UIImage {
    func rotated(by degrees: CGFloat) -> UIImage {
        // Convert degrees to radians
        let radians = degrees * .pi / 180
        
        // Calculate the size of the rotated image
        let rotatedSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size
        
        // Create a graphics context
        UIGraphicsBeginImageContextWithOptions(rotatedSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return self
        }
        
        // Move origin to center
        context.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
        
        // Rotate
        context.rotate(by: radians)
        
        // Draw the image
        draw(in: CGRect(
            x: -size.width / 2,
            y: -size.height / 2,
            width: size.width,
            height: size.height
        ))
        
        guard let rotatedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return self
        }
        
        return rotatedImage
    }
}


