//
//  ManualExpenseView.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/20/25.
//

import SwiftUI
import PhotosUI

struct ManualExpenseView: View {
    let onSaved: () -> Void

    @State private var attachedImage: UIImage? = nil
    @State private var photosPickerItem: PhotosPickerItem? = nil

    @State private var merchantName: String = ""
    @State private var date: Date = Date()
    @State private var totalAmountText: String = ""
    @State private var taxDeductible: Bool = false
    @State private var tagsText: String = ""
    @State private var notes: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let img = attachedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Merchant Name").font(.headline)
                        TextField("Item 1: Sample Item", text: $merchantName)
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(8)
                    }

                    HStack {
                        Text("Date").font(.headline)
                        Spacer()
                        DatePicker("Select date", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Total").font(.headline)
                        TextField("0.0", text: $totalAmountText)
                            .keyboardType(.decimalPad)
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(8)
                    }

                    HStack {
                        Text("Tax Deductible").font(.headline)
                        Spacer()
                        Toggle("", isOn: $taxDeductible).labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tag").font(.headline)
                        ZStack(alignment: .leading) {
                            if tagsText.isEmpty {
                                Text("#work, #meal, #projectX").foregroundColor(.secondary)
                            }
                            TextField("", text: $tagsText)
                                .padding(12)
                                .background(Color.white.opacity(0.001))
                        }
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(8)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes").font(.headline)
                        ZStack(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text("Add notes").foregroundColor(.secondary)
                                    .padding(.top, 8).padding(.leading, 6)
                            }
                            TextEditor(text: $notes)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(Color.clear)
                        }
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(8)
                    }

                    PhotosPicker(selection: $photosPickerItem, matching: .images) {
                        HStack {
                            Image(systemName: "paperclip")
                            Text(attachedImage == nil ? "Attach image or file" : "Replace attachment")
                            Spacer()
                        }
                        .padding(14)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .onChange(of: photosPickerItem) { newItem in
                        guard let item = newItem else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                                attachedImage = img
                            }
                        }
                    }

                    Button(action: { onSaved() }) {
                        Text("Save")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.top, 8)
                }
                .padding(16)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Manual Expense")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { ManualExpenseView(onSaved: {}) }
}



