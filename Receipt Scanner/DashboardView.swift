//
//  DashboardView.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import SwiftUI

struct DashboardView: View {
    let onOpenSettings: () -> Void
    let onOpenHelp: () -> Void
    let onOpenReceipts: () -> Void
    let onOpenReports: () -> Void
    let onScanReceipt: () -> Void
    let onPickFromGallery: () -> Void
    let onManualExpense: () -> Void
    let onCreateReport: () -> Void
    
    @StateObject private var storageManager = StorageManager.shared
    @State private var recentActivities: [RecentActivityItem] = []
    @State private var monthlyStats: (totalAmount: Double, receiptCount: Int) = (0, 0)
    @State private var totalReceiptCount: Int = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Receipt Scanner")
                        .font(.largeTitle.bold())
                    Text("Track your expenses effortlessly")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Quick Actions Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    // Scan Receipt
                    QuickActionCard(
                        title: "Scan Receipt",
                        subtitle: "Take a photo",
                        icon: "camera.fill",
                        color: .blue,
                        action: onScanReceipt
                    )
                    
                    // Pick from Gallery
                    QuickActionCard(
                        title: "From Gallery",
                        subtitle: "Choose existing",
                        icon: "photo.fill",
                        color: .green,
                        action: onPickFromGallery
                    )
                    
                    // Manual Entry
                    QuickActionCard(
                        title: "Manual Entry",
                        subtitle: "Add manually",
                        icon: "pencil.and.outline",
                        color: .orange,
                        action: onManualExpense
                    )
                    
                    // Create Report
                    QuickActionCard(
                        title: "Create Report",
                        subtitle: "Generate PDF",
                        icon: "doc.text.fill",
                        color: .purple,
                        action: onCreateReport
                    )
                }
                .padding(.horizontal)
                
                // Recent Activity Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent Activity")
                            .font(.headline)
                        Spacer()
                        Button("View All", action: onOpenReceipts)
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                    }
                    
                    // Real recent activities
                    VStack(spacing: 8) {
                        if recentActivities.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                Text("No recent activity")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        } else {
                            ForEach(recentActivities) { activity in
                                RecentActivityRow(activity: activity)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Statistics Cards
                HStack(spacing: 12) {
                    StatCard(
                        title: "This Month",
                        value: String(format: "$%.2f", monthlyStats.totalAmount),
                        subtitle: "\(monthlyStats.receiptCount) receipts"
                    )
                    
                    StatCard(
                        title: "Total Saved",
                        value: "\(totalReceiptCount)",
                        subtitle: "receipts"
                    )
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Settings", action: onOpenSettings)
                    Button("Help", action: onOpenHelp)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .onAppear {
            loadDashboardData()
        }
        .onReceive(storageManager.$receipts) { _ in
            loadDashboardData()
        }
        .onReceive(storageManager.$reports) { _ in
            loadDashboardData()
        }
    }
    
    private func loadDashboardData() {
        recentActivities = storageManager.fetchRecentActivities(limit: 5)
        monthlyStats = storageManager.getMonthlyStatistics()
        totalReceiptCount = storageManager.getTotalReceiptCount()
    }
}

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct RecentActivityRow: View {
    let activity: RecentActivityItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Activity thumbnail
            if let thumbnailURL = activity.thumbnailURL {
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
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: activity.type == .receipt ? 
                              (activity.isManualEntry ? "pencil" : "doc.text") : 
                              "doc.text.fill")
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                
                Text(activity.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let amount = activity.amount, let currency = activity.currency {
                    Text("\(currency) \(String(format: "%.2f", amount))")
                        .font(.subheadline.bold())
                        .foregroundColor(.green)
                } else {
                    Text(activity.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(activity.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        DashboardView(
            onOpenSettings: {},
            onOpenHelp: {},
            onOpenReceipts: {},
            onOpenReports: {},
            onScanReceipt: {},
            onPickFromGallery: {},
            onManualExpense: {},
            onCreateReport: {}
        )
    }
}