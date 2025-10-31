//
//  CreateReportView.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import SwiftUI

struct CreateReportView: View {
    let onCancel: () -> Void
    
    @State private var selectedReceipts: Set<UUID> = []
    @State private var reportFormat: ReportFormat = .pdf
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var isGenerating = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showPreview = false
    
    enum ReportFormat: String, CaseIterable {
        case pdf = "PDF"
        case csv = "CSV"
        case excel = "Excel"
        
        var fileExtension: String {
            switch self {
            case .pdf: return "pdf"
            case .csv: return "csv"
            case .excel: return "xlsx"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create Report")
                        .font(.largeTitle.bold())
                    Text("Select receipts and choose format")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Format Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Report Format")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        ForEach(ReportFormat.allCases, id: \.self) { format in
                            Button(action: { reportFormat = format }) {
                                VStack(spacing: 8) {
                                    Image(systemName: formatIcon(for: format))
                                        .font(.title2)
                                        .foregroundColor(reportFormat == format ? .white : .accentColor)
                                    
                                    Text(format.rawValue)
                                        .font(.subheadline)
                                        .foregroundColor(reportFormat == format ? .white : .primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(reportFormat == format ? Color.accentColor : Color(UIColor.secondarySystemBackground))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Receipt Selection
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Select Receipts")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(selectedReceipts.count == allReceipts.count ? "Deselect All" : "Select All") {
                            if selectedReceipts.count == allReceipts.count {
                                selectedReceipts.removeAll()
                            } else {
                                selectedReceipts = Set(allReceipts.compactMap { $0.id })
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                    }
                    .padding(.horizontal)
                    
                    if allReceipts.isEmpty {
                        EmptyReceiptsView()
                    } else {
                        List(allReceipts) { receipt in
                            ReceiptSelectionRow(
                                receipt: receipt,
                                isSelected: selectedReceipts.contains(receipt.id ?? UUID()),
                                onToggle: { 
                                    if let id = receipt.id {
                                        toggleReceipt(id)
                                    }
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                        .listStyle(.plain)
                        .frame(maxHeight: 300)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    // Preview Button
                    Button(action: { showPreview = true }) {
                        HStack {
                            Image(systemName: "eye")
                            Text("Preview Report")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedReceipts.isEmpty ? Color.gray : Color(UIColor.secondarySystemBackground))
                        .foregroundColor(selectedReceipts.isEmpty ? .white : .accentColor)
                        .cornerRadius(12)
                    }
                    .disabled(selectedReceipts.isEmpty)
                    
                    // Generate Button
                    Button(action: generateReport) {
                        HStack {
                            if isGenerating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text(isGenerating ? "Generating..." : "Generate Report")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedReceipts.isEmpty ? Color.gray : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(selectedReceipts.isEmpty || isGenerating)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("Create Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(.accentColor)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ReportShareSheet(items: shareItems)
            }
            .alert("Report Generated", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .navigationDestination(isPresented: $showPreview) {
                if !selectedReceiptsList.isEmpty {
                    ReportPreviewView(
                        receipts: selectedReceiptsList,
                        reportNumber: generateReportNumber(),
                        onBack: { showPreview = false },
                        onGenerate: {
                            showPreview = false
                            generateReport()
                        }
                    )
                }
            }
        }
    }
    
    private var selectedReceiptsList: [Receipt] {
        allReceipts.filter { receipt in
            guard let id = receipt.id else { return false }
            return selectedReceipts.contains(id)
        }
    }
    
    private func generateReportNumber() -> String {
        // Generate report number based on total reports count
        let totalReports = StorageManager.shared.fetchReports().count
        let reportNumber = String(format: "%03d", totalReports + 1)
        return "№\(reportNumber)"
    }
    
    private var allReceipts: [Receipt] {
        StorageManager.shared.fetchReceipts()
    }
    
    private func formatIcon(for format: ReportFormat) -> String {
        switch format {
        case .pdf: return "doc.text.fill"
        case .csv: return "tablecells.fill"
        case .excel: return "tablecells.fill"
        }
    }
    
    private func toggleReceipt(_ id: UUID) {
        if selectedReceipts.contains(id) {
            selectedReceipts.remove(id)
        } else {
            selectedReceipts.insert(id)
        }
    }
    
    private func generateReport() {
        isGenerating = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var reportURL: URL?
            
            switch reportFormat {
            case .pdf:
                reportURL = ReportGenerator.generatePDFReport(receipts: selectedReceiptsList)
            case .csv:
                reportURL = ReportGenerator.generateCSVReport(receipts: selectedReceiptsList)
            case .excel:
                reportURL = ReportGenerator.generateExcelReport(receipts: selectedReceiptsList)
            }
            
            DispatchQueue.main.async {
                isGenerating = false
                
                if let url = reportURL {
                    shareItems = [url]
                    showShareSheet = true
                    alertMessage = "Report generated successfully! You can now share it via email or other apps."
                } else {
                    alertMessage = "Failed to generate report. Please try again."
                    showAlert = true
                }
            }
        }
    }
}

struct ReceiptSelectionRow: View {
    let receipt: Receipt
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.title2)
            }
            .buttonStyle(.plain)
            
            // Receipt thumbnail
            if let thumbnailURL = receipt.thumbnailURL {
                AsyncImage(url: thumbnailURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 50, height: 50)
                .cornerRadius(8)
            } else if let imageURL = receipt.imageURL {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 50, height: 50)
                .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: receipt.isManualEntry ? "pencil" : "doc.text")
                            .foregroundColor(.gray)
                    )
            }
            
            // Receipt details
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.merchantName ?? "Unknown Merchant")
                    .font(.subheadline.bold())
                    .lineLimit(1)
                
                Text(receipt.date ?? Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(receipt.currency ?? "USD") \(String(format: "%.2f", receipt.amount))")
                .font(.subheadline.bold())
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

struct EmptyReceiptsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No Receipts Available")
                .font(.headline)
            
            Text("Add some receipts first to create a report.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    CreateReportView(onCancel: {})
}
