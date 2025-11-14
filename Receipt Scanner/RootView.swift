//
//  RootView.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import SwiftUI
import AVFoundation

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showScanner: Bool = false
    @State private var scannedImageURL: URL? = nil
    @State private var recognizedText: String = ""
    @State private var navigateToDashboardAfterSave: Bool = false
    @State private var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    @State private var showPermissionAlert: Bool = false
    
    // New navigation states
    @State private var showImagePicker: Bool = false
    @State private var showManualExpense: Bool = false
    @State private var showCreateReport: Bool = false
    @State private var showReceiptsList: Bool = false
    @State private var showReportsList: Bool = false
    @State private var showSettings: Bool = false
    @State private var showSupport: Bool = false
    @State private var isProcessingOCR: Bool = false
    @State private var showImageCrop: Bool = false
    @State private var selectedImageForCrop: UIImage? = nil

    var body: some View {
        Group {
            // Always show onboarding if not completed - this ensures users cannot bypass it
            if !hasCompletedOnboarding {
                OnboardingFlowView(
                    onFinish: { action in
                        // Ensure onboarding is marked as complete
                        hasCompletedOnboarding = true
                        switch action {
                        case .scanNow:
                            requestCameraPermissionAndScan()
                        case .useSample:
                            generateSample()
                        }
                    },
                    onRequestScan: { requestCameraPermissionAndScan() },
                    onRequestSample: { generateSample() }
                )
            } else if let url = scannedImageURL {
                NavigationStack {
                    EditExpenseView(
                        imageURL: url,
                        recognizedText: recognizedText,
                        onScanAnother: {
                            // Reset to scan another receipt
                            scannedImageURL = nil
                            requestCameraPermissionAndScan()
                        },
                        onSaved: {
                            // After save, go to dashboard
                            scannedImageURL = nil
                            recognizedText = ""
                            navigateToDashboardAfterSave = true
                        }
                    )
                }
            } else {
                // Dashboard for subsequent app opens
                NavigationStack {
                    DashboardView(
                        onOpenSettings: { showSettings = true },
                        onOpenHelp: { showSupport = true },
                        onOpenReceipts: { showReceiptsList = true },
                        onOpenReports: { showReportsList = true },
                        onScanReceipt: { requestCameraPermissionAndScan() },
                        onPickFromGallery: { showImagePicker = true },
                        onManualExpense: { showManualExpense = true },
                        onCreateReport: { showCreateReport = true }
                    )
                }
            }
        }
        .sheet(isPresented: $showScanner, onDismiss: {
            print("Scanner sheet dismissed")
        }) {
            ScannerContainer { result in
                print("ScannerContainer completion handler called")
                switch result {
                case .success(let output):
                    print("Scanner completed successfully - Image URL: \(output.imageURL)")
                    print("Scanner completed successfully - OCR Text: \(output.recognizedText)")
                    // Update state BEFORE dismissing sheet
                    self.scannedImageURL = output.imageURL
                    self.recognizedText = output.recognizedText
                    print("State updated - scannedImageURL: \(String(describing: self.scannedImageURL))")
                    // Dismiss scanner sheet after state is updated
                    self.showScanner = false
                case .failure(let error):
                    print("Scanner error: \(error.localizedDescription)")
                    self.showScanner = false
                }
            }
        }
        .sheet(isPresented: $showImagePicker, onDismiss: {
            // Handle case where picker is dismissed without selection
            print("Image picker dismissed")
        }) {
            ImagePicker(selectedImage: .constant(nil), onImageSelected: { selectedImage in
                // Dismiss picker first
                DispatchQueue.main.async {
                    showImagePicker = false
                    
                    guard let image = selectedImage else {
                        print("No image selected from gallery")
                        return
                    }
                    
                    print("Image selected from gallery: \(image.size)")
                    // Small delay to ensure picker is dismissed before showing crop view
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedImageForCrop = image
                        showImageCrop = true
                    }
                }
            })
        }
        .sheet(isPresented: $showImageCrop) {
            if let image = selectedImageForCrop {
                ImageCropView(
                    image: image,
                    onCrop: { croppedImage in
                        DispatchQueue.main.async {
                            showImageCrop = false
                            selectedImageForCrop = nil
                            print("Processing cropped image from gallery: \(croppedImage.size)")
                            // Process the cropped image
                            processImageFromGallery(croppedImage)
                        }
                    },
                    onCancel: {
                        DispatchQueue.main.async {
                            showImageCrop = false
                            selectedImageForCrop = nil
                        }
                    }
                )
            }
        }
        .overlay {
            if isProcessingOCR {
                OCRProcessingOverlay()
            }
        }
        .sheet(isPresented: $showManualExpense) {
            NavigationStack {
                ManualExpenseView(
                    onSaved: {
                        showManualExpense = false
                    },
                    onCancel: {
                        showManualExpense = false
                    }
                )
            }
        }
        .sheet(isPresented: $showCreateReport) {
            NavigationStack {
                CreateReportView(
                    onCancel: {
                        showCreateReport = false
                    }
                )
            }
        }
        .sheet(isPresented: $showReceiptsList) {
            NavigationStack {
                ReceiptsListView()
            }
        }
        .sheet(isPresented: $showReportsList) {
            NavigationStack {
                ReportsListView()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showSupport) {
            SupportView()
        }
        .alert("Camera Permission Required", isPresented: $showPermissionAlert) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable camera access in Settings to scan receipts.")
        }
        .onChange(of: navigateToDashboardAfterSave) { toDashboard in
            if toDashboard {
                // Ensure we're not on edit anymore; reset flag
                navigateToDashboardAfterSave = false
            }
        }
        .onAppear {
            checkCameraPermission()
        }
        .preferredColorScheme(themeManager.colorScheme)
    }

    private func checkCameraPermission() {
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    private func requestCameraPermissionAndScan() {
        switch cameraPermissionStatus {
        case .authorized:
            showScanner = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermissionStatus = granted ? .authorized : .denied
                    if granted {
                        showScanner = true
                    } else {
                        showPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showPermissionAlert = true
        @unknown default:
            showPermissionAlert = true
        }
    }

    private func processImageFromGallery(_ image: UIImage) {
        print("=== Processing image from gallery ===")
        print("Image size: \(image.size)")
        print("Image scale: \(image.scale)")
        
        // Show loading indicator
        DispatchQueue.main.async {
            self.isProcessingOCR = true
        }
        
        // Process image on background queue (similar to scanner)
        DispatchQueue.global(qos: .userInitiated).async {
            // Apply scanner-like processing first (with timeout fallback)
            print("Applying scanner processing...")
            var processingCompleted = false
            let lock = NSLock()
            
            // Set a timeout to ensure we don't wait forever (reduced to 8 seconds)
            let timeoutWorkItem = DispatchWorkItem {
                lock.lock()
                defer { lock.unlock() }
                
                guard !processingCompleted else { return }
                processingCompleted = true
                print("Scanner processing timeout, using original image")
                
                // Save original image on background queue
                DispatchQueue.global(qos: .userInitiated).async {
                    self.saveAndProcessImage(image, originalImage: image)
                }
            }
            
            // Schedule timeout
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 8.0, execute: timeoutWorkItem)
            
            // Start image processing
            ImageProcessor.processScannedImage(from: image) { processedImage in
                lock.lock()
                defer { lock.unlock() }
                
                guard !processingCompleted else { return }
                processingCompleted = true
                timeoutWorkItem.cancel()
                
                // Ensure we're on background queue for file operations
                DispatchQueue.global(qos: .userInitiated).async {
                    let imageToSave = processedImage ?? image
                    if processedImage == nil {
                        print("Scanner processing failed, using original image")
                    } else {
                        print("Scanner processing completed successfully - image is now black & white scanned-like")
                    }
                    // Save the processed image (which is black & white scanned-like)
                    self.saveAndProcessImage(imageToSave, originalImage: image)
                }
            }
        }
    }
    
    private func saveAndProcessImage(_ image: UIImage, originalImage: UIImage? = nil) {
        // Save image using ZIP compression (like scanner)
        print("Saving image as ZIP...")
        let result = StorageManager.shared.saveReceiptImageAsZip(image, compressionQuality: 0.7)
        var finalURL: URL? = result.zipURL
        
        if let zipURL = result.zipURL {
            print("ZIP saved successfully: \(zipURL.path)")
            // Verify file exists
            if FileManager.default.fileExists(atPath: zipURL.path) {
                print("ZIP file verified at path")
            } else {
                print("WARNING: ZIP file does not exist at path!")
            }
        } else {
            print("ZIP save failed, falling back to regular JPEG...")
        }
        
        // Fallback to regular save if ZIP fails
        if finalURL == nil {
            print("Using fallback JPEG save...")
            let timestamp = Int(Date().timeIntervalSince1970)
            let uuid = UUID().uuidString.prefix(8)
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let jpgURL = documentsDir.appendingPathComponent("receipt_\(timestamp)_\(uuid).jpg")
            
            if let data = image.jpegData(compressionQuality: 0.7) {
                do {
                    try data.write(to: jpgURL, options: [.atomic])
                    finalURL = jpgURL
                    print("Fallback JPEG saved: \(jpgURL.path)")
                    
                    // Verify file exists
                    if FileManager.default.fileExists(atPath: jpgURL.path) {
                        print("JPEG file verified at path")
                    } else {
                        print("WARNING: JPEG file does not exist at path!")
                    }
                } catch {
                    print("Failed to save JPEG: \(error)")
                }
            } else {
                print("Failed to generate JPEG data")
            }
        }
        
        guard let url = finalURL else {
            print("ERROR: Failed to save image - no URL available")
            DispatchQueue.main.async {
                self.isProcessingOCR = false
            }
            return
        }
        
        print("Final image URL: \(url.path)")
        let fileExists = FileManager.default.fileExists(atPath: url.path)
        print("File exists: \(fileExists)")
        
        // Verify the file was actually saved
        guard fileExists else {
            print("ERROR: File does not exist after save attempt")
            DispatchQueue.main.async {
                self.isProcessingOCR = false
            }
            return
        }
        
        // Perform OCR asynchronously on the processed image (or original if no processing was done)
        print("Starting OCR for gallery image...")
        let imageForOCR = originalImage ?? image // Use original for OCR as it has better text recognition
        OCRTextRecognizer.recognizeText(from: imageForOCR) { text in
            print("OCR completed for gallery image")
            DispatchQueue.main.async {
                print("Setting scannedImageURL to: \(url.path)")
                print("Image size: \(image.size)")
                self.scannedImageURL = url
                self.recognizedText = text ?? ""
                self.isProcessingOCR = false
                print("=== Gallery image processing complete ===")
                print("scannedImageURL is now: \(String(describing: self.scannedImageURL?.path))")
            }
        }
    }

    private func generateSample() {
        guard let image = SampleReceiptGenerator.generate() else { return }
        processImageFromGallery(image)
    }
}

struct OCRProcessingOverlay: View {
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                    .scaleEffect(1.5)
                
                VStack(spacing: 8) {
                    Text("Scanning Receipt...")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Extracting text from image")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 40)
        }
    }
}

#Preview {
    RootView()
}


