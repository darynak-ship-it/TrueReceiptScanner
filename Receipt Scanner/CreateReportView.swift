//
//  CreateReportView.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import SwiftUI

struct CreateReportView: View {
    let onCancel: () -> Void
    
    @StateObject private var storageManager = StorageManager.shared
    
    @State private var selectedReceipts: Set<UUID> = []
    @State private var reportFormat: ReportFormat = .pdf
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var isGenerating = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showPreview = false

    @State private var dateFilterMode: DateFilterMode = .all
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()
    @State private var selectedWeekIDs: Set<String> = []
    @State private var selectedMonthIDs: Set<String> = []
    @State private var selectedQuarterIDs: Set<String> = []
    @State private var selectedCategories: Set<String> = []
    @State private var selectedPaymentMethods: Set<String> = []
    @State private var taxDeductibleOnly = false
    @State private var selectedTags: Set<String> = []
    @State private var sortOption: SortOption = .dateNewest
    @State private var currentReportNumber: String = ""
    @State private var currentReportDate: Date = Date()
    @State private var showFilters = false
    
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

    enum DateFilterMode: String, CaseIterable {
        case all
        case customRange
        case weeks
        case months
        case quarters

        var label: String {
            switch self {
            case .all: return "All"
            case .customRange: return "Custom"
            case .weeks: return "Weeks"
            case .months: return "Months"
            case .quarters: return "Quarters"
            }
        }
    }

    enum SortOption: String, CaseIterable {
        case dateNewest = "Date (Newest)"
        case dateOldest = "Date (Oldest)"
        case amountHighLow = "Amount (High-Low)"
        case amountLowHigh = "Amount (Low-High)"
        case merchantAZ = "Merchant (A-Z)"
        case merchantZA = "Merchant (Z-A)"

        var icon: String {
            switch self {
            case .dateNewest, .dateOldest:
                return "calendar"
            case .amountHighLow, .amountLowHigh:
                return "dollarsign"
            case .merchantAZ, .merchantZA:
                return "bag"
            }
        }
    }

    struct DateIntervalOption: Identifiable, Hashable {
        let id: String
        let title: String
        let subtitle: String?
        let startDate: Date
        let endDate: Date
    }
    
    var body: some View {
        NavigationStack {
            mainContent
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
                    previewDestination
                }
                .onAppear {
                    storageManager.refreshReceipts()
                }
                .onChange(of: storageManager.receipts) { _ in
                    syncSelectionWithVisibleReceipts()
                }
                .onChange(of: dateFilterMode) { mode in
                    handleDateFilterModeChange(mode)
                }
                .onChange(of: customStartDate) { _ in
                    normalizeCustomRangeValues()
                    syncSelectionWithVisibleReceipts()
                }
                .onChange(of: customEndDate) { _ in
                    normalizeCustomRangeValues()
                    syncSelectionWithVisibleReceipts()
                }
                .onChange(of: selectedWeekIDs) { _ in 
                    syncSelectionWithVisibleReceipts() 
                }
                .onChange(of: selectedMonthIDs) { _ in 
                    syncSelectionWithVisibleReceipts() 
                }
                .onChange(of: selectedQuarterIDs) { _ in 
                    syncSelectionWithVisibleReceipts() 
                }
                .onChange(of: selectedCategories) { _ in 
                    syncSelectionWithVisibleReceipts() 
                }
                .onChange(of: selectedPaymentMethods) { _ in 
                    syncSelectionWithVisibleReceipts() 
                }
                .onChange(of: taxDeductibleOnly) { _ in 
                    syncSelectionWithVisibleReceipts() 
                }
                .onChange(of: selectedTags) { _ in 
                    syncSelectionWithVisibleReceipts() 
                }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    formatSelectionSection
                    if showFilters {
                        filterControlsSection
                    } else {
                        filterToggleButton
                    }
                    receiptSelectionSection
                }
                .padding(.top, 20)
            }

            actionButtons
                .padding(.horizontal)
                .padding(.bottom, 20)
        }
    }
    
    @ViewBuilder
    private var previewDestination: some View {
        if !selectedReceiptsList.isEmpty {
            ReportPreviewView(
                receipts: selectedReceiptsList,
                reportNumber: currentReportNumber,
                generatedAt: currentReportDate,
                onBack: { showPreview = false },
                onGenerate: {
                    showPreview = false
                    generateReport()
                }
            )
        }
    }

    private var headerSection: some View {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create Report")
                        .font(.largeTitle.bold())
            Text("Filter expenses, select receipts, and choose a format.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
    }
                
    private var formatSelectionSection: some View {
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
    }

    private var filterControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Filters & Sorting")
                    .font(.headline)

                Spacer()

                Button(action: { showFilters = false }) {
                    Image(systemName: "chevron.up")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }

                if filtersActive {
                    Button("Reset") {
                        resetFilters()
                    }
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                dateFilterSection
                Divider()
                categoryFilterSection
                paymentMethodFilterSection
                taxFilterSection
                tagsFilterSection
                Divider()
                sortSection
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    private var filterToggleButton: some View {
        Button(action: { showFilters = true }) {
            HStack {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.headline)
                Text("Filters & Sorting")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private var dateFilterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Date")
                .font(.subheadline)
                .fontWeight(.semibold)

            Picker("Date Filter", selection: $dateFilterMode) {
                ForEach(DateFilterMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch dateFilterMode {
            case .all:
                Text("Including receipts from all time.")
                    .font(.caption)
                    .foregroundColor(.secondary)

            case .customRange:
                VStack(alignment: .leading, spacing: 8) {
                    DatePicker("Start", selection: $customStartDate, displayedComponents: .date)
                    DatePicker(
                        "End",
                        selection: $customEndDate,
                        in: customStartDate...Date(),
                        displayedComponents: .date
                    )
                }

            case .weeks:
                selectableChipsView(
                    title: "Select week(s)",
                    options: availableWeeks,
                    selected: selectedWeekIDs,
                    onToggle: toggleWeek
                )

            case .months:
                selectableChipsView(
                    title: "Select month(s)",
                    options: availableMonths,
                    selected: selectedMonthIDs,
                    onToggle: toggleMonth
                )

            case .quarters:
                selectableChipsView(
                    title: "Select quarter(s)",
                    options: availableQuarters,
                    selected: selectedQuarterIDs,
                    onToggle: toggleQuarter
                )
            }
        }
    }

    private func selectableChipsView(
        title: String,
        options: [DateIntervalOption],
        selected: Set<String>,
        onToggle: @escaping (DateIntervalOption) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            if options.isEmpty {
                Text("No options available yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(options) { option in
                            FilterChip(
                                title: option.title,
                                subtitle: option.subtitle,
                                isSelected: selected.contains(option.id),
                                action: { onToggle(option) }
                            )
                        }
                    }
                }
            }
        }
    }

    private var categoryFilterSection: some View {
        filterMenuSection(
            title: "Category",
            placeholder: "All categories",
            selectedItems: selectedCategories,
            availableItems: availableCategories,
            onToggle: toggleCategory,
            onClear: { selectedCategories.removeAll() }
        )
    }

    private var paymentMethodFilterSection: some View {
        filterMenuSection(
            title: "Payment Method",
            placeholder: "All payment methods",
            selectedItems: selectedPaymentMethods,
            availableItems: availablePaymentMethods,
            onToggle: togglePaymentMethod,
            onClear: { selectedPaymentMethods.removeAll() }
        )
    }

    private var tagsFilterSection: some View {
        filterMenuSection(
            title: "Tags",
            placeholder: "All tags",
            selectedItems: selectedTags,
            availableItems: availableTags,
            onToggle: toggleTag,
            onClear: { selectedTags.removeAll() }
        )
    }

    private func filterMenuSection(
        title: String,
        placeholder: String,
        selectedItems: Set<String>,
        availableItems: [String],
        onToggle: @escaping (String) -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            if availableItems.isEmpty {
                Text("No \(title.lowercased()) available yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Menu {
                    ForEach(availableItems, id: \.self) { item in
                        Button(action: { onToggle(item) }) {
                            Label(item, systemImage: selectedItems.contains(item) ? "checkmark.circle.fill" : "circle")
                        }
                    }

                    if !selectedItems.isEmpty {
                        Divider()
                        Button("Clear Selection", role: .destructive, action: onClear)
                    }
                } label: {
                    FilterMenuLabel(
                        title: selectedItems.isEmpty ? placeholder : "\(selectedItems.count) selected",
                        count: selectedItems.count
                    )
                }

                if !selectedItems.isEmpty {
                    Text(selectedItems.sorted().joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }

    private var taxFilterSection: some View {
        Toggle(isOn: $taxDeductibleOnly) {
            Text("Only tax-deductible receipts")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    private var sortSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sort")
                .font(.subheadline)
                .fontWeight(.semibold)

            Menu {
                Picker("Sort receipts", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                HStack {
                    Image(systemName: sortOption.icon)
                        .foregroundColor(.accentColor)
                    Text(sortOption.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(10)
            }
        }
    }

    private var receiptSelectionSection: some View {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Select Receipts")
                            .font(.headline)
                        
                        Spacer()
                        
                if !filteredAndSortedReceipts.isEmpty {
                    Text("\(filteredAndSortedReceipts.count) receipt\(filteredAndSortedReceipts.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Button(allVisibleSelected ? "Deselect All" : "Select All") {
                    let visibleIDs = filteredReceiptIDs
                    if allVisibleSelected {
                        selectedReceipts.subtract(visibleIDs)
                            } else {
                        selectedReceipts.formUnion(visibleIDs)
                            }
                        }
                .disabled(filteredReceiptIDs.isEmpty)
                        .font(.subheadline)
                .foregroundColor(filteredReceiptIDs.isEmpty ? .secondary : .accentColor)
                    }
                    .padding(.horizontal)
                    
                    if allReceipts.isEmpty {
                        EmptyReceiptsView()
            } else if filteredAndSortedReceipts.isEmpty {
                FilteredReceiptsEmptyView(isFiltering: filtersActive)
                    } else {
                List {
                    ForEach(filteredAndSortedReceipts) { receipt in
                            ReceiptSelectionRow(
                                receipt: receipt,
                            isSelected: receipt.id.flatMap { selectedReceipts.contains($0) } ?? false,
                                onToggle: { 
                                    if let id = receipt.id {
                                        toggleReceipt(id)
                                    }
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                        }
                        .listStyle(.plain)
                .frame(minHeight: 200, maxHeight: 400)
            }
                    }
                }
                
    private var actionButtons: some View {
                VStack(spacing: 12) {
            Button(action: {
                guard !filteredAndSortedReceipts.isEmpty else { return }
                guard !selectedReceiptsList.isEmpty else {
                    showSelectionAlert()
                    return
                }
                prepareReportMetadata()
                showPreview = true
            }) {
                        HStack {
                            Image(systemName: "eye")
                            Text("Preview Report")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                .background(selectedReceiptsList.isEmpty ? Color.gray : Color(UIColor.secondarySystemBackground))
                .foregroundColor(selectedReceiptsList.isEmpty ? .white : .accentColor)
                        .cornerRadius(12)
                    }
            .disabled(selectedReceiptsList.isEmpty)

            Button(action: {
                guard !selectedReceiptsList.isEmpty else {
                    showSelectionAlert()
                    return
                }
                prepareReportMetadata()
                generateReport()
            }) {
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
                .background(selectedReceiptsList.isEmpty || isGenerating ? Color.gray : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
            .disabled(selectedReceiptsList.isEmpty || isGenerating)
        }
    }

    private var selectedReceiptsList: [Receipt] {
        filteredAndSortedReceipts.filter { receipt in
            guard let id = receipt.id else { return false }
            return selectedReceipts.contains(id)
        }
    }

    private var filteredReceiptIDs: Set<UUID> {
        Set(filteredAndSortedReceipts.compactMap { $0.id })
    }
    
    private var allVisibleSelected: Bool {
        let visibleIDs = filteredReceiptIDs
        guard !visibleIDs.isEmpty else { return false }
        let selectedVisibleCount = selectedReceipts.intersection(visibleIDs).count
        return selectedVisibleCount == visibleIDs.count
    }

    private var allReceipts: [Receipt] {
        storageManager.receipts
    }

    private var availableCategories: [String] {
        // Predefined categories
        let predefinedCategories = [
            "Travel expenses",
            "Food & Dining",
            "Accommodation",
            "Office supplies",
            "Technology and equipment",
            "Software and subscriptions",
            "Education",
            "Professional memberships",
            "Home office expenses",
            "Uniform",
            "Sports",
            "Health",
            "Communication expenses",
            "Relocation expenses",
            "Client-related expenses",
            "Other"
        ]
        
        // Get categories from receipts
        let receiptCategories = Set(allReceipts.compactMap {
            let trimmed = ($0.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        })
        
        // Combine and deduplicate
        let allCategories = Set(predefinedCategories).union(receiptCategories)
        return allCategories.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var availablePaymentMethods: [String] {
        // Predefined payment methods
        let predefinedMethods = [
            "Credit Card",
            "Debit Card",
            "PayPal",
            "Apple Pay/Google Pay",
            "Bank Transfer",
            "Cash",
            "Prepaid Cards",
            "Other"
        ]
        
        // Get payment methods from receipts
        let receiptMethods = Set(allReceipts.compactMap {
            let trimmed = ($0.paymentMethod ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        })
        
        // Combine and deduplicate
        let allMethods = Set(predefinedMethods).union(receiptMethods)
        return allMethods.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var availableTags: [String] {
        let tagSet = allReceipts.reduce(into: Set<String>()) { partialResult, receipt in
            let components = (receipt.tags ?? "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            components.forEach { tag in
                if !tag.isEmpty {
                    partialResult.insert(tag)
                }
            }
        }
        return tagSet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var availableWeeks: [DateIntervalOption] {
        let calendar = Calendar.current
        var options: [DateIntervalOption] = []
        let reference = calendar.startOfDay(for: Date())

        for offset in 0..<10 {
            guard
                let candidate = calendar.date(byAdding: .weekOfYear, value: -offset, to: reference),
                let interval = calendar.dateInterval(of: .weekOfYear, for: candidate)
            else { continue }

            let end = calendar.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
            let title = formattedDateRange(start: interval.start, end: end, short: true)
            let weekNumber = calendar.component(.weekOfYear, from: interval.start)
            let subtitle = "Week \(weekNumber)"
            let identifier = intervalIdentifier(start: interval.start, end: end)
            options.append(DateIntervalOption(id: identifier, title: title, subtitle: subtitle, startDate: interval.start, endDate: end))
        }

        return options
    }

    private var availableMonths: [DateIntervalOption] {
        let calendar = Calendar.current
        var options: [DateIntervalOption] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"

        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"

        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()

        for offset in 0..<12 {
            guard
                let monthStart = calendar.date(byAdding: .month, value: -offset, to: currentMonthStart),
                let interval = calendar.dateInterval(of: .month, for: monthStart)
            else { continue }

            let end = calendar.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
            let identifier = intervalIdentifier(start: interval.start, end: end)
            options.append(
                DateIntervalOption(
                    id: identifier,
                    title: formatter.string(from: monthStart),
                    subtitle: yearFormatter.string(from: monthStart),
                    startDate: interval.start,
                    endDate: end
                )
            )
        }

        return options
    }

    private var availableQuarters: [DateIntervalOption] {
        let calendar = Calendar.current
        var options: [DateIntervalOption] = []
        let now = Date()
        guard let currentQuarterStart = startOfQuarter(for: now) else { return options }

        for offset in 0..<8 {
            guard
                let quarterStart = calendar.date(byAdding: .month, value: -(offset * 3), to: currentQuarterStart),
                let end = calendar.date(byAdding: .month, value: 3, to: quarterStart)
            else { continue }

            let quarterEnd = calendar.date(byAdding: .second, value: -1, to: end) ?? end
            let quarter = calendar.component(.quarter, from: quarterStart)
            let startMonth = formattedMonthShort(quarterStart)
            let endMonth = formattedMonthShort(quarterEnd)

            let title = "\(startMonth) - \(endMonth)"
            let year = calendar.component(.year, from: quarterStart)
            let subtitle = "Q\(quarter) \(year)"

            let identifier = intervalIdentifier(start: quarterStart, end: quarterEnd)
            options.append(DateIntervalOption(id: identifier, title: title, subtitle: subtitle, startDate: quarterStart, endDate: quarterEnd))
        }

        return options
    }

    private var filteredReceipts: [Receipt] {
        allReceipts.filter { receipt in
            // Apply date filter if receipt has a date, otherwise include it if date filter is "all"
            if let receiptDate = receipt.date {
                if !passesDateFilter(for: receiptDate) {
                    return false
                }
            } else {
                // If receipt has no date, only include it if date filter is "all"
                if dateFilterMode != .all {
                    return false
                }
            }

            if taxDeductibleOnly && !receipt.isTaxDeductible {
                return false
            }

            if !selectedCategories.isEmpty {
                let category = (receipt.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !selectedCategories.contains(where: { $0.caseInsensitiveCompare(category) == .orderedSame }) {
                    return false
                }
            }

            if !selectedPaymentMethods.isEmpty {
                let method = (receipt.paymentMethod ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !selectedPaymentMethods.contains(where: { $0.caseInsensitiveCompare(method) == .orderedSame }) {
                    return false
                }
            }

            if !selectedTags.isEmpty {
                let receiptTags = Set(
                    (receipt.tags ?? "")
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                        .filter { !$0.isEmpty }
                )

                if receiptTags.isEmpty {
                    return false
                }

                let normalizedSelected = selectedTags.map { $0.lowercased() }
                if receiptTags.isDisjoint(with: normalizedSelected) {
                    return false
                }
            }

            return true
        }
    }

    private var filteredAndSortedReceipts: [Receipt] {
        let receipts = filteredReceipts

        return receipts.sorted { lhs, rhs in
            switch sortOption {
            case .dateNewest:
                return (lhs.date ?? .distantPast) > (rhs.date ?? .distantPast)
            case .dateOldest:
                return (lhs.date ?? .distantFuture) < (rhs.date ?? .distantFuture)
            case .amountHighLow:
                return lhs.amount > rhs.amount
            case .amountLowHigh:
                return lhs.amount < rhs.amount
            case .merchantAZ:
                let left = (lhs.merchantName ?? "").lowercased()
                let right = (rhs.merchantName ?? "").lowercased()
                return left == right ? (lhs.date ?? .distantPast) > (rhs.date ?? .distantPast) : left < right
            case .merchantZA:
                let left = (lhs.merchantName ?? "").lowercased()
                let right = (rhs.merchantName ?? "").lowercased()
                return left == right ? (lhs.date ?? .distantPast) > (rhs.date ?? .distantPast) : left > right
            }
        }
    }

    private var filtersActive: Bool {
        let dateActive: Bool = {
            switch dateFilterMode {
            case .all:
                return false
            case .customRange:
                return true
            case .weeks:
                return !selectedWeekIDs.isEmpty
            case .months:
                return !selectedMonthIDs.isEmpty
            case .quarters:
                return !selectedQuarterIDs.isEmpty
            }
        }()

        return dateActive
        || !selectedCategories.isEmpty
        || !selectedPaymentMethods.isEmpty
        || taxDeductibleOnly
        || !selectedTags.isEmpty
    }

    private func passesDateFilter(for date: Date) -> Bool {
        switch dateFilterMode {
        case .all:
            return true
        case .customRange:
            let range = currentCustomRange()
            return date >= range.start && date <= range.end
        case .weeks:
            guard !selectedWeekIDs.isEmpty else { return true }
            return availableWeeks
                .filter { selectedWeekIDs.contains($0.id) }
                .contains { date >= $0.startDate && date <= $0.endDate }
        case .months:
            guard !selectedMonthIDs.isEmpty else { return true }
            return availableMonths
                .filter { selectedMonthIDs.contains($0.id) }
                .contains { date >= $0.startDate && date <= $0.endDate }
        case .quarters:
            guard !selectedQuarterIDs.isEmpty else { return true }
            return availableQuarters
                .filter { selectedQuarterIDs.contains($0.id) }
                .contains { date >= $0.startDate && date <= $0.endDate }
        }
    }

    private func currentCustomRange() -> (start: Date, end: Date) {
        let start = min(customStartDate, customEndDate)
        let end = max(customStartDate, customEndDate)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: start)
        let endOfDay = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: calendar.startOfDay(for: end)) ?? end
        return (startOfDay, endOfDay)
    }

    private func formattedDateRange(start: Date, end: Date, short: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = short ? .medium : .long
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    private func intervalIdentifier(start: Date, end: Date) -> String {
        let startValue = String(format: "%.0f", start.timeIntervalSince1970)
        let endValue = String(format: "%.0f", end.timeIntervalSince1970)
        return "\(startValue)-\(endValue)"
    }

    private func formattedMonthShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private func startOfQuarter(for date: Date) -> Date? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let month = components.month, let year = components.year else { return nil }

        let quarter = ((month - 1) / 3) * 3 + 1
        var startComponents = DateComponents()
        startComponents.year = year
        startComponents.month = quarter
        startComponents.day = 1

        return calendar.date(from: startComponents)
    }

    private func toggleReceipt(_ id: UUID) {
        if selectedReceipts.contains(id) {
            selectedReceipts.remove(id)
        } else {
            selectedReceipts.insert(id)
        }
    }

    private func toggleWeek(_ option: DateIntervalOption) {
        if selectedWeekIDs.contains(option.id) {
            selectedWeekIDs.remove(option.id)
        } else {
            selectedWeekIDs.insert(option.id)
        }
    }

    private func toggleMonth(_ option: DateIntervalOption) {
        if selectedMonthIDs.contains(option.id) {
            selectedMonthIDs.remove(option.id)
        } else {
            selectedMonthIDs.insert(option.id)
        }
    }

    private func toggleQuarter(_ option: DateIntervalOption) {
        if selectedQuarterIDs.contains(option.id) {
            selectedQuarterIDs.remove(option.id)
        } else {
            selectedQuarterIDs.insert(option.id)
        }
    }

    private func toggleCategory(_ category: String) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    private func togglePaymentMethod(_ method: String) {
        if selectedPaymentMethods.contains(method) {
            selectedPaymentMethods.remove(method)
        } else {
            selectedPaymentMethods.insert(method)
        }
    }

    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }

    private func handleDateFilterModeChange(_ mode: DateFilterMode) {
        switch mode {
        case .all:
            selectedWeekIDs.removeAll()
            selectedMonthIDs.removeAll()
            selectedQuarterIDs.removeAll()
        case .customRange:
            selectedWeekIDs.removeAll()
            selectedMonthIDs.removeAll()
            selectedQuarterIDs.removeAll()
        case .weeks:
            selectedMonthIDs.removeAll()
            selectedQuarterIDs.removeAll()
        case .months:
            selectedWeekIDs.removeAll()
            selectedQuarterIDs.removeAll()
        case .quarters:
            selectedWeekIDs.removeAll()
            selectedMonthIDs.removeAll()
        }
        syncSelectionWithVisibleReceipts()
    }

    private func resetFilters() {
        dateFilterMode = .all
        customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        customEndDate = Date()
        selectedWeekIDs.removeAll()
        selectedMonthIDs.removeAll()
        selectedQuarterIDs.removeAll()
        selectedCategories.removeAll()
        selectedPaymentMethods.removeAll()
        selectedTags.removeAll()
        taxDeductibleOnly = false
        sortOption = .dateNewest
        syncSelectionWithVisibleReceipts()
    }

    private func prepareReportMetadata() {
        currentReportNumber = generateReportNumber()
        currentReportDate = Date()
    }

    private func normalizeCustomRangeValues() {
        if customEndDate < customStartDate {
            customEndDate = customStartDate
        }
    }

    private func showSelectionAlert() {
        alertMessage = "Select at least one receipt before generating a report."
        showAlert = true
    }

    private func syncSelectionWithVisibleReceipts() {
        let visibleIDs = filteredReceiptIDs
        selectedReceipts = selectedReceipts.intersection(visibleIDs)
    }
    
    private func generateReportNumber() -> String {
        let totalReports = StorageManager.shared.fetchReports().count
        let reportNumber = String(format: "%03d", totalReports + 1)
        return "№\(reportNumber)"
    }
    
    private func formatIcon(for format: ReportFormat) -> String {
        switch format {
        case .pdf: return "doc.text.fill"
        case .csv: return "tablecells.fill"
        case .excel: return "tablecells.fill"
        }
    }
    
    private func generateReport() {
        guard !selectedReceiptsList.isEmpty else {
            showSelectionAlert()
            return
        }

        let receiptsToExport = selectedReceiptsList
        let reportNumber = currentReportNumber.isEmpty ? generateReportNumber() : currentReportNumber
        let reportDate = currentReportDate

        isGenerating = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var reportURL: URL?
            
            switch reportFormat {
            case .pdf:
                reportURL = ReportGenerator.generatePDFReport(
                    receipts: receiptsToExport,
                    reportNumber: reportNumber,
                    generatedAt: reportDate
                )
            case .csv:
                reportURL = ReportGenerator.generateCSVReport(receipts: receiptsToExport)
            case .excel:
                reportURL = ReportGenerator.generateExcelReport(receipts: receiptsToExport)
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

struct FilterChip: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .accentColor : .primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color(UIColor.tertiarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color(UIColor.separator.withAlphaComponent(0.3)), lineWidth: isSelected ? 1.5 : 1)
            )
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

struct FilterMenuLabel: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            if count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .cornerRadius(6)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(10)
    }
}

struct FilteredReceiptsEmptyView: View {
    let isFiltering: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isFiltering ? "line.3.horizontal.decrease.circle" : "tray")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text(isFiltering ? "No receipts match your filters" : "No receipts to display")
                .font(.headline)

            Text(isFiltering ? "Try adjusting the filters or resetting them to see more receipts." : "Add receipts to start building your report.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
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
