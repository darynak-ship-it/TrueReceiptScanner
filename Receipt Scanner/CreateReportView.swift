//
//  CreateReportView.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/20/25.
//

import SwiftUI

private enum SortOption: String, CaseIterable, Identifiable { case date = "📆Date", category = "🗂️Category", tag = "🏷️Tag", payment = "💳Payment"; var id: String { rawValue } }
private enum ExportFormat: String, CaseIterable, Identifiable { case pdf = "🔺PDF", excel = "🟢Excel", csv = "🟨CSV"; var id: String { rawValue } }

struct CreateReportView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var reportName: String = ""
    @State private var sortBy: SortOption = .date
    @State private var exportFormat: ExportFormat = .pdf
    @State private var attachReceipts: Bool = false
    @State private var showAddExpenses: Bool = false
    @State private var selectedExpenseIds: Set<UUID> = []
    @State private var showPreview: Bool = false
    @State private var previewText: String = ""
    @State private var showShare: Bool = false
    @State private var shareURL: URL? = nil

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Report name", text: $reportName)
                }

                Section("PROPERTIES") {
                    NavigationLink {
                        OptionsListView(title: "Sort by", options: SortOption.allCases.map { $0.rawValue }, selected: sortBy.rawValue) { chosen in
                            sortBy = SortOption.allCases.first { $0.rawValue == chosen } ?? .date
                        }
                    } label: {
                        HStack { Text("Sort by"); Spacer(); Text(sortBy.rawValue).foregroundColor(.green) }
                    }

                    NavigationLink {
                        OptionsListView(title: "Export format", options: ExportFormat.allCases.map { $0.rawValue }, selected: exportFormat.rawValue) { chosen in
                            exportFormat = ExportFormat.allCases.first { $0.rawValue == chosen } ?? .pdf
                        }
                    } label: {
                        HStack { Text("Export format"); Spacer(); Text(exportFormat.rawValue).foregroundColor(.green) }
                    }

                    Toggle("Attach receipts", isOn: $attachReceipts)
                }

                Section("INCLUDED EXPENSES") {
                    Button {
                        showAddExpenses = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill").foregroundColor(.green)
                            Text("Add Expenses")
                        }
                    }
                }
            }

            HStack {
                Button(action: openPreview) {
                    Text("Preview")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                }
                Button(action: openShare) {
                    HStack { Image(systemName: "square.and.arrow.up"); Text("Send") }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle("Generate Report")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Back") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) { Button("Save") { dismiss() } }
        }
        .sheet(isPresented: $showAddExpenses) {
            NavigationStack { MultiselectExpensesView(selected: $selectedExpenseIds) }
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showPreview) {
            NavigationStack {
                VStack {
                    Text("Preview (\(exportFormat.rawValue))").font(.headline)
                    ScrollView { Text(previewText).padding() }
                }
                .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Back") { showPreview = false } } }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showShare) {
            if let url = shareURL { ShareSheet(activityItems: [url]) }
        }
        .onDisappear { if let url = shareURL { try? FileManager.default.removeItem(at: url) } }
    }

    private func openPreview() {
        previewText = "Report: \(reportName.isEmpty ? "Untitled" : reportName)\nFormat: \(exportFormat.rawValue)\nItems: \(selectedExpenseIds.count)"
        showPreview = true
    }

    private func openShare() {
        let content = "Report: \(reportName.isEmpty ? "Untitled" : reportName)\nFormat: \(exportFormat.rawValue)\nItems: \(selectedExpenseIds.count)"
        let data = Data(content.utf8)
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("report-preview.txt")
        try? data.write(to: tmp)
        shareURL = tmp
        showShare = true
    }
}

private struct OptionsListView: View {
    let title: String
    let options: [String]
    @State var selected: String
    let onPick: (String) -> Void

    var body: some View {
        List(options, id: \.self) { opt in
            HStack {
                Text(opt)
                Spacer()
                if opt == selected { Image(systemName: "checkmark") }
            }
            .contentShape(Rectangle())
            .onTapGesture { selected = opt; onPick(opt) }
        }
        .navigationTitle(title)
    }
}

private struct MultiselectExpensesView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selected: Set<UUID>

    private let mock: [(UUID, String, String)] = (0..<20).map { (UUID(), "Merchant \($0)", "$\(String(format: "%.2f", Double($0) * 3 + 2))") }

    var body: some View {
        List {
            ForEach(mock, id: \.0) { item in
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.1)
                        Text(item.2).foregroundColor(.secondary).font(.subheadline)
                    }
                    Spacer()
                    if selected.contains(item.0) { Image(systemName: "checkmark") }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selected.contains(item.0) { selected.remove(item.0) } else { selected.insert(item.0) }
                }
            }
        }
        .navigationTitle("Select Expenses")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: activityItems, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack { CreateReportView() }
}



