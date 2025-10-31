//
//  ReportsListView.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import SwiftUI
import CoreData

struct ReportsListView: View {
    @StateObject private var storageManager = StorageManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            SearchBar(text: $searchText)
                .padding(.horizontal)
                .padding(.top, 8)
            
            Divider()
            
            // Reports List
            if filteredReports.isEmpty {
                EmptyReportsView()
            } else {
                List(filteredReports) { report in
                    ReportRowView(report: report) {
                        if let fileURL = report.fileURL {
                            shareItems = [fileURL]
                            showShareSheet = true
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            storageManager.deleteReport(report)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
                    .foregroundColor(.accentColor)
            }
        }
        .onAppear {
            // Refresh data when view appears
            storageManager.refreshReports()
        }
        .sheet(isPresented: $showShareSheet) {
            ReportShareSheet(items: shareItems)
        }
    }
    
    private var filteredReports: [Report] {
        let reports = storageManager.fetchReports()
        
        if searchText.isEmpty {
            return reports
        }
        
        return reports.filter { report in
            let title = report.title ?? ""
            let type = report.type ?? ""
            return title.localizedCaseInsensitiveContains(searchText) ||
                   type.localizedCaseInsensitiveContains(searchText)
        }
    }
}

struct ReportRowView: View {
    let report: Report
    let onShare: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Report icon
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: iconForReportType(report.type ?? ""))
                        .font(.title2)
                        .foregroundColor(.accentColor)
                )
            
            // Report details
            VStack(alignment: .leading, spacing: 4) {
                Text(report.title ?? "Untitled Report")
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    Text(report.type ?? "PDF")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text("\(report.receiptCount) receipts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(report.createdAt ?? Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // File size
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatFileSize(report.fileSize))
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func iconForReportType(_ type: String) -> String {
        switch type.lowercased() {
        case "pdf":
            return "doc.text.fill"
        case "csv":
            return "tablecells.fill"
        case "excel", "xlsx":
            return "tablecells.fill"
        default:
            return "doc.text.fill"
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
}

struct EmptyReportsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Reports Found")
                .font(.title2.bold())
            
            Text("Create your first report by selecting receipts and generating a PDF, CSV, or Excel file.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}

#Preview {
    NavigationStack {
        ReportsListView()
    }
}

