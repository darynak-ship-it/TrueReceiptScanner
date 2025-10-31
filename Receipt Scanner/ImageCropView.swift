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
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    // Image display (non-interactive, crop overlay handles interaction)
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .onAppear {
                            calculateImageDisplaySize(in: geometry.size)
                        }
                        .onChange(of: geometry.size) { _ in
                            calculateImageDisplaySize(in: geometry.size)
                        }
                    
                    // Crop overlay
                    if !isDetecting {
                        CropOverlayView(
                            cropRect: $cropRect,
                            imageSize: image.size,
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        cropImage()
                    }
                    .foregroundColor(.accentColor)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                detectReceiptArea()
            }
        }
    }
    
    private func calculateImageDisplaySize(in containerSize: CGSize) {
        let imageAspect = image.size.width / image.size.height
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
            setupDefaultCropRect()
            return
        }
        
        isDetecting = true
        
        let request = VNDetectRectanglesRequest { request, error in
            DispatchQueue.main.async {
                isDetecting = false
                
                if let error = error {
                    print("Error detecting receipt: \(error.localizedDescription)")
                    setupDefaultCropRect()
                    return
                }
                
                guard let results = request.results as? [VNRectangleObservation],
                      let rectangle = results.first,
                      rectangle.confidence > 0.7 else {
                    print("No receipt detected, using default crop")
                    setupDefaultCropRect()
                    return
                }
                
                // Convert Vision coordinates to image coordinates
                // Vision uses normalized coordinates (0-1) with origin at bottom-left
                // UIImage uses origin at top-left
                let imageWidth = image.size.width
                let imageHeight = image.size.height
                
                // Convert normalized coordinates to image coordinates
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
                
                cropRect = CGRect(
                    x: max(0, minX - paddingX),
                    y: max(0, minY - paddingY),
                    width: min(imageWidth - (minX - paddingX), maxX - minX + (paddingX * 2)),
                    height: min(imageHeight - (minY - paddingY), maxY - minY + (paddingY * 2))
                )
                
                print("Detected receipt area: \(cropRect) with confidence: \(rectangle.confidence)")
            }
        }
        
        request.minimumAspectRatio = 0.2
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.2
        request.minimumConfidence = 0.6
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    isDetecting = false
                    print("Failed to detect receipt: \(error)")
                    setupDefaultCropRect()
                }
            }
        }
    }
    
    private func setupDefaultCropRect() {
        // Set initial crop rect to center 80% of image
        let cropWidth = image.size.width * 0.8
        let cropHeight = image.size.height * 0.8
        let cropX = (image.size.width - cropWidth) / 2
        let cropY = (image.size.height - cropHeight) / 2
        
        cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
    }
    
    private func cropImage() {
        // Crop the image using the crop rect
        guard let cgImage = image.cgImage else {
            print("Failed to get CGImage")
            onCancel()
            return
        }
        
        // Ensure crop rect is within image bounds
        let boundedRect = cropRect.intersection(CGRect(origin: .zero, size: image.size))
        
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
        
        let croppedImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
        print("Successfully cropped image: \(croppedImage.size)")
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
        let scaleX = imageSize.width / imageDisplaySize.width
        let scaleY = imageSize.height / imageDisplaySize.height
        
        // Use last crop rect as base to prevent cumulative errors
        var newRect = lastCropRect
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
        let scaleX = imageSize.width / imageDisplaySize.width
        let scaleY = imageSize.height / imageDisplaySize.height
        
        // Use last crop rect as base to prevent cumulative errors
        var newRect = lastCropRect
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

