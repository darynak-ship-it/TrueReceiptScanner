//
//  ReceiptsListView.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/20/25.
//

import SwiftUI

struct ReceiptsListView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("HISTORY") {
                ForEach(0..<8, id: \.self) { idx in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sample Merchant \(idx + 1)").font(.headline)
                            Text("2025-10-0\(idx % 9 + 1) • $\(String(format: "%.2f", Double(idx + 1) * 5))")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .onDelete { _ in }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Receipts")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
    }
}

#Preview {
    NavigationStack { ReceiptsListView() }
}



