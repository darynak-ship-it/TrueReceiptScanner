//
//  ReceiptsListView.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import SwiftUI
import CoreData

struct ReceiptsListView: View {
    @StateObject private var storageManager = StorageManager.shared
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""
    @State private var selectedFilter: ReceiptFilter = .all
    @State private var sortOption: ReceiptSortOption = .dateDesc
    
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            SearchBar(text: $searchText)
                .padding(.horizontal)
                .padding(.top, 8)
            
            // Filter and Sort Controls
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Filter Options
                    ForEach(ReceiptFilter.allCases, id: \.self) { filter in
                        FilterChip(
                            title: filter.rawValue,
                            isSelected: selectedFilter == filter,
                            action: { selectedFilter = filter }
                        )
                    }
                    
                    Spacer()
                    
                    // Sort Menu
                    Menu {
                        ForEach(ReceiptSortOption.allCases, id: \.self) { sort in
                            Button(sort.rawValue) {
                                sortOption = sort
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Sort")
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            
            Divider()
            
            // Receipts List
            if filteredReceipts.isEmpty {
                EmptyStateView()
            } else {
                List(filteredReceipts) { receipt in
                    ReceiptRowView(receipt: receipt)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Receipts")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            // Refresh data when view appears
            storageManager.refreshReceipts()
        }
    }
    
    // Real Core Data fetch with filtering and sorting
    private var filteredReceipts: [Receipt] {
        var receipts = storageManager.fetchReceipts(filter: selectedFilter, searchText: searchText)
        
        // Apply sorting
        switch sortOption {
        case .dateDesc:
            receipts.sort { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }
        case .dateAsc:
            receipts.sort { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }
        case .amountDesc:
            receipts.sort { $0.amount > $1.amount }
        case .amountAsc:
            receipts.sort { $0.amount < $1.amount }
        case .merchant:
            receipts.sort { ($0.merchantName ?? "") < ($1.merchantName ?? "") }
        }
        
        return receipts
    }
}

struct SearchBar: View {
    @Binding var text: String
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search receipts...", text: $text)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(themeManager.secondaryBackgroundColor)
        .cornerRadius(12)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(UIColor.secondarySystemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

struct ReceiptRowView: View {
    let receipt: Receipt
    
    var body: some View {
        HStack(spacing: 12) {
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
                .frame(width: 60, height: 60)
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
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: receipt.isManualEntry ? "pencil" : "doc.text")
                            .foregroundColor(.gray)
                    )
            }
            
            // Receipt details
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.merchantName ?? "Unknown Merchant")
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    Text(receipt.category ?? "Other")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(4)
                    
                    if receipt.isTaxDeductible {
                        Text("Tax Deductible")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    if receipt.isManualEntry {
                        Text("Manual")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Text(receipt.date ?? Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(receipt.currency ?? "USD") \(String(format: "%.2f", receipt.amount))")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(receipt.paymentMethod ?? "Other")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Receipts Found")
                .font(.title2.bold())
            
            Text("Start by scanning your first receipt or add one manually.")
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
        ReceiptsListView()
    }
}