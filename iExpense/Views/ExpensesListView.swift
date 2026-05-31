//
//  ExpensesListView.swift
//  iExpense
//

import SwiftUI

struct ExpensesListView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore

    @ObservedObject var viewModel: ExpenseViewModel
    @StateObject private var analyticsViewModel = AnalyticsViewModel(expenses: [])

    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var recentlyDeletedExpenses: [Expense] = []
    @State private var showUndoSnackbar = false
    @State private var undoTimer: Timer?
    @State private var selectedExpenseToEdit: Expense?
    @State private var showingFilterSheet = false
    @State private var selectedSortOption: SortOption = .dateDescending
    @State private var selectedTransactionFilter: TransactionFilter = .all
    @State private var searchText = ""
    @State private var selectedCategoryIDs: Set<String> = []
    @State private var isListLoaded = false

    private let monthHistoryLength = 61

    enum SortOption: String, CaseIterable, Identifiable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case amountDescending = "Highest Amount"
        case amountAscending = "Lowest Amount"
        case titleAscending = "Title A-Z"

        var id: String { rawValue }
    }

    enum TransactionFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case expenses = "Expenses"
        case incomes = "Incomes"

        var id: String { rawValue }

        func matches(_ transaction: Expense) -> Bool {
            switch self {
            case .all:
                return true
            case .expenses:
                return transaction.type == .expense
            case .incomes:
                return transaction.type == .income
            }
        }
    }

    private var currencyCode: String {
        settingsViewModel.selectedCurrency
    }

    private var filteredExpenses: [Expense] {
        var result = viewModel.expenses.filter { expense in
            let month = Calendar.current.component(.month, from: expense.date)
            let year = Calendar.current.component(.year, from: expense.date)
            let category = categoryStore.category(for: expense)

            let matchesDate = month == selectedMonth && year == selectedYear
            let matchesSearch = searchText.isEmpty ||
                expense.title.localizedCaseInsensitiveContains(searchText) ||
                category.displayName.localizedCaseInsensitiveContains(searchText) ||
                (expense.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
            let matchesCategory = selectedCategoryIDs.isEmpty || selectedCategoryIDs.contains(expense.categoryID)
            let matchesType = selectedTransactionFilter.matches(expense)

            return matchesDate && matchesSearch && matchesCategory && matchesType
        }

        switch selectedSortOption {
        case .dateDescending:
            result.sort { $0.date > $1.date }
        case .dateAscending:
            result.sort { $0.date < $1.date }
        case .amountDescending:
            result.sort { $0.price > $1.price }
        case .amountAscending:
            result.sort { $0.price < $1.price }
        case .titleAscending:
            result.sort { $0.title < $1.title }
        }

        return result
    }

    private var totalSpent: Double {
        filteredExpenses.filter { $0.type == .expense }.reduce(0) { $0 + $1.price }
    }

    private var totalIncome: Double {
        filteredExpenses.filter { $0.type == .income }.reduce(0) { $0 + $1.price }
    }

    private var netCashflow: Double {
        totalIncome - totalSpent
    }

    private var groupedExpenses: [String: [Expense]] {
        Dictionary(grouping: filteredExpenses) { $0.categoryID }
    }

    private var filterCategories: [FinanceCategory] {
        categoryStore.categoriesForFilter(usedCategoryIDs: Set(viewModel.expenses.map(\.categoryID)))
    }

    private var filterCategoryIDs: [String] {
        filterCategories.map(\.id)
    }

    private var visibleCategoryIDs: [String] {
        categoryStore.orderedCategoryIDs(for: Set(groupedExpenses.keys))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    monthYearPicker
                        .padding(.top, 8)

                    if !filteredExpenses.isEmpty {
                        summaryCard
                            .padding(.horizontal)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                    }

                    if filteredExpenses.isEmpty {
                        emptyStateView
                            .transition(.opacity)
                            .animation(.easeInOut, value: filteredExpenses.isEmpty)
                    } else {
                        transactionList
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search transactions")
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    toolbarFilters
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        selectedExpenseToEdit = Expense(title: "", price: 0, date: Date(), category: .food)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                refreshExpenses()
            }
            .onAppear {
                analyticsViewModel.updateExpenses(viewModel.expenses)
                if selectedCategoryIDs.isEmpty {
                    selectedCategoryIDs = Set(filterCategoryIDs)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        isListLoaded = true
                    }
                }
            }
            .onChange(of: filterCategoryIDs) { oldCategoryIDs, newCategoryIDs in
                syncSelectedCategoryIDs(oldCategoryIDs: oldCategoryIDs, newCategoryIDs: newCategoryIDs)
            }
            .onChange(of: viewModel.expenses) {
                analyticsViewModel.updateExpenses(viewModel.expenses)
            }
            .sheet(item: $selectedExpenseToEdit) { expenseToEdit in
                if expenseToEdit.title.isEmpty {
                    AddExpenseView(viewModel: viewModel)
                } else {
                    EditExpenseView(viewModel: viewModel, expense: expenseToEdit)
                        .id(expenseToEdit.id)
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterCategoriesView(selectedCategoryIDs: $selectedCategoryIDs, categories: filterCategories)
                    .presentationDetents([.medium])
            }
            .overlay(undoSnackbar, alignment: .bottom)
        }
    }

    private var transactionList: some View {
        List {
            ForEach(visibleCategoryIDs, id: \.self) { categoryID in
                let category = categoryStore.category(for: categoryID)

                Section {
                    ForEach(groupedExpenses[categoryID] ?? []) { expense in
                        ExpenseRowContent(
                            expense: expense,
                            currencyCode: currencyCode,
                            onEdit: {
                                selectedExpenseToEdit = expense
                            },
                            onDelete: {
                                deleteExpenseByID(expense)
                            }
                        )
                    }
                } header: {
                    HStack {
                        Image(systemName: category.iconName)
                            .foregroundColor(.white)
                            .font(.caption)
                            .frame(width: 28, height: 28)
                            .background(category.color)
                            .clipShape(Circle())

                        Text(category.displayName)
                            .font(.headline)

                        Spacer()

                        let categoryTotal = (groupedExpenses[categoryID] ?? []).reduce(0) { total, transaction in
                            total + (transaction.type == .income ? transaction.price : -transaction.price)
                        }
                        Text(categoryTotal, format: .currency(code: currencyCode))
                            .font(.subheadline)
                            .foregroundColor(categoryTotal >= 0 ? .green : .secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .listStyle(.insetGrouped)
        .opacity(isListLoaded ? 1 : 0)
        .animation(.easeIn(duration: 0.3), value: isListLoaded)
    }

    private func syncSelectedCategoryIDs(oldCategoryIDs: [String], newCategoryIDs: [String]) {
        let oldSet = Set(oldCategoryIDs)
        let newSet = Set(newCategoryIDs)
        selectedCategoryIDs.formUnion(newSet.subtracting(oldSet))
        selectedCategoryIDs = selectedCategoryIDs.intersection(newSet)
    }

    private var toolbarFilters: some View {
        HStack(spacing: 12) {
            Menu {
                Picker("Sort by", selection: $selectedSortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }

            Menu {
                Picker("Type", selection: $selectedTransactionFilter) {
                    ForEach(TransactionFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
            } label: {
                Label("Type", systemImage: "line.3.horizontal.decrease")
            }

            Button {
                showingFilterSheet = true
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
            }
        }
    }

    private var monthYearPicker: some View {
        MonthYearPicker(
            selectedMonth: $selectedMonth,
            selectedYear: $selectedYear,
            monthsToShow: monthHistoryLength
        )
        .padding(.horizontal)
    }

    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                summaryMetric(title: "Income", amount: totalIncome, color: .green)
                Divider()
                summaryMetric(title: "Spent", amount: totalSpent, color: .primary)
                Divider()
                summaryMetric(title: "Net", amount: netCashflow, color: netCashflow >= 0 ? .green : .red)
                Divider()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Items")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("\(filteredExpenses.count)")
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }

            if analyticsViewModel.currentBudget > 0 {
                budgetProgress
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }

    private func summaryMetric(title: String, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(amount, format: .currency(code: currencyCode))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var budgetProgress: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Monthly Budget")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(totalSpent, format: .currency(code: currencyCode))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("of")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(analyticsViewModel.currentBudget, format: .currency(code: currencyCode))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            let progress = min(1.0, totalSpent / analyticsViewModel.currentBudget)
            let progressColor: Color = progress < 0.75 ? .blue : (progress < 0.9 ? .orange : .red)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * CGFloat(progress), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 70))
                .foregroundColor(.gray.opacity(0.6))
                .padding()

            Text("No Transactions Found")
                .font(.title2)
                .fontWeight(.bold)

            if !searchText.isEmpty {
                Text("Try adjusting your search or filters")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else if selectedCategoryIDs.count < filterCategoryIDs.count {
                Text("Try selecting more categories in the filter")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button {
                    selectedCategoryIDs = Set(filterCategoryIDs)
                } label: {
                    Text("Reset Filters")
                        .foregroundColor(.accentColor)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentColor, lineWidth: 1)
                        )
                }
                .padding(.top, 8)
            } else {
                Text("Add your first transaction for \(Calendar.current.monthSymbols[selectedMonth - 1]) \(String(selectedYear))")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button {
                    selectedExpenseToEdit = Expense(title: "", price: 0, date: Date(), category: .food)
                } label: {
                    let addExpenseLabel: some View =
                        Label("Add Transaction", systemImage: "plus")
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)

                    if #available(iOS 26.0, *) {
                        addExpenseLabel
                            .glassEffect(.regular.tint(.blue).interactive())
                    } else {
                        addExpenseLabel
                            .background(Color.accentColor)
                            .cornerRadius(10)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var undoSnackbar: some View {
        VStack {
            Spacer()
            if showUndoSnackbar {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)

                    Text("Transaction deleted")
                        .foregroundColor(.white)

                    Spacer()

                    Button("Undo") {
                        undoDelete()
                    }
                    .foregroundColor(.yellow)
                    .fontWeight(.bold)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.85))
                        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(), value: showUndoSnackbar)
            }
        }
    }

    private func refreshExpenses() {
        viewModel.loadExpenses()
    }

    private func deleteExpenseByID(_ expense: Expense) {
        if let index = viewModel.expenses.firstIndex(where: { $0.id == expense.id }) {
            recentlyDeletedExpenses = [expense]
            viewModel.expenses.remove(at: index)
            viewModel.saveExpenses()

            showUndoSnackbar = true

            undoTimer?.invalidate()
            undoTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
                showUndoSnackbar = false
                recentlyDeletedExpenses.removeAll()
            }
        }
    }

    private func undoDelete() {
        undoTimer?.invalidate()
        viewModel.expenses.append(contentsOf: recentlyDeletedExpenses)
        viewModel.saveExpenses()
        recentlyDeletedExpenses.removeAll()
        showUndoSnackbar = false
    }
}

struct ExpenseRowView: View {
    @EnvironmentObject private var categoryStore: CategoryStore

    let expense: Expense
    let currencyCode: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .center, spacing: 2) {
                Text(dayNumber)
                    .font(.system(size: 18, weight: .semibold))

                Text(monthShort)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            .frame(width: 40)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: category.iconName)
                        .font(.caption2)
                        .foregroundColor(category.color)

                    Text(category.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(amountText)
                .font(.system(.headline, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(expense.type.amountColor)
        }
        .padding(.vertical, 6)
    }

    private var category: FinanceCategory {
        categoryStore.category(for: expense)
    }

    private var amountText: String {
        let formatted = expense.price.formatted(.currency(code: currencyCode))
        return expense.type == .income ? "+\(formatted)" : formatted
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: expense.date)
    }

    private var monthShort: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: expense.date)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, d MMM yyyy"
        return formatter.string(from: expense.date)
    }
}

struct FilterCategoriesView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedCategoryIDs: Set<String>
    let categories: [FinanceCategory]
    @State private var tempSelectedCategoryIDs: Set<String>

    init(selectedCategoryIDs: Binding<Set<String>>, categories: [FinanceCategory]) {
        self._selectedCategoryIDs = selectedCategoryIDs
        self.categories = categories
        self._tempSelectedCategoryIDs = State(initialValue: selectedCategoryIDs.wrappedValue)
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(categories) { category in
                        HStack {
                            Image(systemName: category.iconName)
                                .foregroundColor(.white)
                                .font(.caption)
                                .frame(width: 28, height: 28)
                                .background(category.color)
                                .clipShape(Circle())

                            Text(category.displayName)
                                .font(.body)

                            Spacer()

                            if tempSelectedCategoryIDs.contains(category.id) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if tempSelectedCategoryIDs.contains(category.id) {
                                if tempSelectedCategoryIDs.count > 1 {
                                    tempSelectedCategoryIDs.remove(category.id)
                                }
                            } else {
                                tempSelectedCategoryIDs.insert(category.id)
                            }
                        }
                    }
                } header: {
                    Text("Categories")
                } footer: {
                    Text("Select which categories to display")
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        selectedCategoryIDs = tempSelectedCategoryIDs
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ExpenseRowContent: View {
    let expense: Expense
    let currencyCode: String
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ExpenseRowView(expense: expense, currencyCode: currencyCode)
            .contentShape(Rectangle())
            .onTapGesture {
                onEdit()
            }
            .contextMenu {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading) {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .trailing) {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)
            }
    }
}

#Preview {
    ExpensesListView(viewModel: ExpenseViewModel())
        .environmentObject(SettingsViewModel())
        .environmentObject(CategoryStore())
}
