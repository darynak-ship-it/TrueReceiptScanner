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
    @State private var showSettings: Bool = false
    @State private var showSupport: Bool = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingFlowView(
                    onFinish: { action in
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
                        onOpenReports: {},
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
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: .constant(nil), onImageSelected: { selectedImage in
                showImagePicker = false
                if let image = selectedImage {
                    // Save image and perform OCR
                    if let url = FileStorage.save(image: image) {
                        self.scannedImageURL = url
                        self.recognizedText = OCRTextRecognizer.recognizeTextSync(from: image) ?? ""
                    }
                }
            })
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

    private func generateSample() {
        guard let image = SampleReceiptGenerator.generate() else { return }
        if let url = FileStorage.save(image: image) {
            self.scannedImageURL = url
            self.recognizedText = OCRTextRecognizer.recognizeTextSync(from: image) ?? ""
        }
    }
}

#Preview {
    RootView()
}


