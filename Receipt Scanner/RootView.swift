//
//  RootView.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var showScanner: Bool = false
    @State private var scannedImageURL: URL? = nil
    @State private var recognizedText: String = ""
    @State private var navigateToDashboardAfterSave: Bool = false
    
    // New navigation states
    @State private var showImagePicker: Bool = false
    @State private var showManualExpense: Bool = false
    @State private var showCreateReport: Bool = false
    @State private var showReceiptsList: Bool = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingFlowView(
                    onFinish: { action in
                        hasCompletedOnboarding = true
                        switch action {
                        case .scanNow:
                            showScanner = true
                        case .useSample:
                            generateSample()
                        }
                    },
                    onRequestScan: { showScanner = true },
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
                            showScanner = true
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
                        onOpenSettings: {},
                        onOpenHelp: {},
                        onOpenReceipts: { showReceiptsList = true },
                        onOpenReports: {},
                        onScanReceipt: { showScanner = true },
                        onPickFromGallery: { showImagePicker = true },
                        onManualExpense: { showManualExpense = true },
                        onCreateReport: { showCreateReport = true }
                    )
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            ScannerContainer { result in
                showScanner = false
                switch result {
                case .success(let output):
                    self.scannedImageURL = output.imageURL
                    self.recognizedText = output.recognizedText
                case .failure:
                    break
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
        .onChange(of: navigateToDashboardAfterSave) { _, toDashboard in
            if toDashboard {
                // Ensure we're not on edit anymore; reset flag
                navigateToDashboardAfterSave = false
            }
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


