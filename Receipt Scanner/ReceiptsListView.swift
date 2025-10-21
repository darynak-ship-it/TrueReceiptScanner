//
//  ReceiptsListView.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import SwiftUI

struct ReceiptsListView: View {
    @State private var searchText = ""
    @State private var selectedFilter: FilterOption = .all
    @State private var sortOption: SortOption = .dateDesc
    
    enum FilterOption: String, CaseIterable {
        case all = "All"
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case taxDeductible = "Tax Deductible"
    }
    
    enum SortOption: String, CaseIterable {
        case dateDesc = "Date (Newest)"
        case dateAsc = "Date (Oldest)"
        case amountDesc = "Amount (Highest)"
        case amountAsc = "Amount (Lowest)"
        case merchant = "Merchant (A-Z)"
    }
    
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
                    ForEach(FilterOption.allCases, id: \.self) { filter in
                        FilterChip(
                            title: filter.rawValue,
                            isSelected: selectedFilter == filter,
                            action: { selectedFilter = filter }
                        )
                    }
                    
                    Spacer()
                    
                    // Sort Menu
                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { sort in
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
    }
    
    // Mock data for now - replace with actual Core Data fetch
    private var filteredReceipts: [MockReceipt] {
        var receipts = MockReceipt.sampleData
        
        // Apply search filter
        if !searchText.isEmpty {
            receipts = receipts.filter { receipt in
                receipt.merchantName.localizedCaseInsensitiveContains(searchText) ||
                receipt.category.localizedCaseInsensitiveContains(searchText) ||
                receipt.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Apply category filter
        switch selectedFilter {
        case .all:
            break
        case .thisMonth:
            receipts = receipts.filter { receipt in
                Calendar.current.isDate(receipt.date, equalTo: Date(), toGranularity: .month)
            }
        case .lastMonth:
            let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            receipts = receipts.filter { receipt in
                Calendar.current.isDate(receipt.date, equalTo: lastMonth, toGranularity: .month)
            }
        case .taxDeductible:
            receipts = receipts.filter { $0.isTaxDeductible }
        }
        
        // Apply sorting
        switch sortOption {
        case .dateDesc:
            receipts.sort { $0.date > $1.date }
        case .dateAsc:
            receipts.sort { $0.date < $1.date }
        case .amountDesc:
            receipts.sort { $0.amount > $1.amount }
        case .amountAsc:
            receipts.sort { $0.amount < $1.amount }
        case .merchant:
            receipts.sort { $0.merchantName < $1.merchantName }
        }
        
        return receipts
    }
}

struct SearchBar: View {
    @Binding var text: String
    
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
        .background(Color(UIColor.secondarySystemBackground))
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
    let receipt: MockReceipt
    
    var body: some View {
        HStack(spacing: 12) {
            // Receipt thumbnail
            AsyncImage(url: receipt.imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 60, height: 60)
            .cornerRadius(8)
            
            // Receipt details
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.merchantName)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    Text(receipt.category)
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
                }
                
                Text(receipt.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", receipt.amount))")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(receipt.paymentMethod)
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

// Mock data structure - replace with Core Data model
struct MockReceipt: Identifiable {
    let id = UUID()
    let merchantName: String
    let amount: Double
    let date: Date
    let category: String
    let paymentMethod: String
    let isTaxDeductible: Bool
    let tags: [String]
    let imageURL: URL?
    
    static let sampleData: [MockReceipt] = [
        MockReceipt(
            merchantName: "Coffee Shop",
            amount: 4.50,
            date: Date(),
            category: "Food & Dining",
            paymentMethod: "Credit Card",
            isTaxDeductible: false,
            tags: ["coffee", "morning"],
            imageURL: nil
        ),
        MockReceipt(
            merchantName: "Office Supplies Store",
            amount: 25.99,
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            category: "Office supplies",
            paymentMethod: "Debit Card",
            isTaxDeductible: true,
            tags: ["office", "supplies"],
            imageURL: nil
        ),
        MockReceipt(
            merchantName: "Gas Station",
            amount: 45.20,
            date: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
            category: "Travel expenses",
            paymentMethod: "Credit Card",
            isTaxDeductible: true,
            tags: ["gas", "travel"],
            imageURL: nil
        )
    ]
}

#Preview {
    NavigationStack {
        ReceiptsListView()
    }
}