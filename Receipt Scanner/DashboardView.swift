//
//  DashboardView.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/20/25.
//

import SwiftUI
import UIKit

struct DashboardView: View {
    let onOpenSettings: () -> Void
    let onOpenHelp: () -> Void
    let onOpenReceipts: () -> Void
    let onOpenReports: () -> Void
    let onScanReceipt: () -> Void
    let onPickFromGallery: () -> Void
    let onManualExpense: () -> Void
    let onCreateReport: () -> Void

    @State private var showAddMenu: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                header
                content
                Spacer()
            }

            addButton
        }
        .sheet(isPresented: $showAddMenu) {
            AddNewItemSheet(
                onScan: {
                    showAddMenu = false
                    onScanReceipt()
                },
                onPick: {
                    showAddMenu = false
                    onPickFromGallery()
                },
                onManual: {
                    showAddMenu = false
                    onManualExpense()
                },
                onCreateReport: {
                    showAddMenu = false
                    onCreateReport()
                },
                onCancel: { showAddMenu = false }
            )
            .presentationDetents([.height(360), .medium])
            .presentationBackground(.ultraThinMaterial)
        }
        .background(Color(UIColor.systemGray6).ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.title2)
            }
            Spacer()
            Text("Receipt Scanner")
                .font(.title2).bold()
            Spacer()
            Button(action: onOpenHelp) {
                Image(systemName: "questionmark.circle")
                    .font(.title2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var content: some View {
        HStack(spacing: 16) {
            DashboardCard(title: "Receipts", emoji: "🧾", action: onOpenReceipts)
            DashboardCard(title: "Reports", emoji: "📊", action: onOpenReports)
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
    }

    private var addButton: some View {
        Button(action: { showAddMenu = true }) {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 64, height: 64)
                .background(Color.green)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
        }
        .padding(20)
    }
}

private struct DashboardCard: View {
    let title: String
    let emoji: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Text(emoji)
                    .font(.system(size: 36))
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
}

private struct AddNewItemSheet: View {
    let onScan: () -> Void
    let onPick: () -> Void
    let onManual: () -> Void
    let onCreateReport: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            Text("Add New Item")
                .font(.headline)
                .padding(.top, 4)

            VStack(spacing: 10) {
                AddRow(title: "Snap a Receipt", systemImage: "camera.viewfinder", action: onScan)
                AddRow(title: "Choose from Gallery", systemImage: "photo.on.rectangle", action: onPick)
                AddRow(title: "Manually Add Expense", systemImage: "square.and.pencil", action: onManual)
                AddRow(title: "Create a report", systemImage: "doc.text", action: onCreateReport)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Button(action: onCancel) {
                Text("Cancel")
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .background(VisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial)))
    }
}

private struct AddRow: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .frame(width: 28)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// UIKit blur bridge
private struct VisualEffectView: UIViewRepresentable {
    let effect: UIVisualEffect?
    func makeUIView(context: Context) -> UIVisualEffectView { UIVisualEffectView(effect: effect) }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { uiView.effect = effect }
}

#Preview {
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



