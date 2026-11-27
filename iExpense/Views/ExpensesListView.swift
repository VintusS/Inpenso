//
//  ExpensesListView.swift
//  iExpense
//

import SwiftUI

struct ExpensesListView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @EnvironmentObject private var walletsViewModel: WalletsViewModel

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
    @State private var amountBounds = TransactionAmountBounds()
    @State private var selectedCategoryIDs: Set<String> = []
    @State private var isListLoaded = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                return transaction.type != .income
            case .incomes:
                return transaction.type == .income
            }
        }
    }

    private var currencyCode: String {
        settingsViewModel.selectedCurrency
    }

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredExpenses: [Expense] {
        let query = searchQuery
        let calendar = Calendar.current
        var result = viewModel.expenses.filter { expense in
            guard amountBounds.contains(expense.price),
                  selectedTransactionFilter.matches(expense),
                  selectedCategoryIDs.isEmpty || selectedCategoryIDs.contains(categoryStore.category(for: expense).id)
            else { return false }

            if query.isEmpty {
                let date = calendar.dateComponents([.month, .year], from: expense.date)
                return date.month == selectedMonth && date.year == selectedYear
            }

            return expense.title.localizedCaseInsensitiveContains(query)
                || categoryStore.category(for: expense).displayName.localizedCaseInsensitiveContains(query)
                || expense.notes?.localizedCaseInsensitiveContains(query) == true
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

    /// Purchases minus refunds listed this month, floored at zero.
    private var totalSpent: Double {
        max(0, filteredExpenses.reduce(0) { total, transaction in
            switch transaction.type {
            case .expense:
                return total + transaction.price
            case .refund:
                return total - transaction.price
            case .income:
                return total
            }
        })
    }

    private var totalIncome: Double {
        filteredExpenses.filter { $0.type == .income }.reduce(0) { $0 + $1.price }
    }

    private var netCashflow: Double {
        filteredExpenses.netCashflow
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
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if dynamicTypeSize.isAccessibilitySize {
                    if filteredExpenses.isEmpty {
                        ScrollView {
                            transactionHeader
                            emptyStateView
                        }
                    } else {
                        transactionList
                    }
                } else {
                    VStack(spacing: 0) {
                        transactionHeader

                        if filteredExpenses.isEmpty {
                            emptyStateView
                                .transition(.opacity)
                                .animation(reduceMotion ? nil : .easeInOut, value: filteredExpenses.isEmpty)
                        } else {
                            transactionList
                        }
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
                        Label("Add Transaction", systemImage: "plus")
                            .labelStyle(.iconOnly)
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
                    withAnimation(reduceMotion ? nil : .default) {
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
                } else if let transfer = walletsViewModel.transfers.first(where: { $0.feeExpenseID == expenseToEdit.id }) {
                    TransferSheet(walletsViewModel: walletsViewModel, transfer: transfer)
                } else {
                    EditExpenseView(viewModel: viewModel, expense: expenseToEdit)
                        .id(expenseToEdit.id)
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                TransactionFiltersView(
                    selectedCategoryIDs: $selectedCategoryIDs,
                    amountBounds: $amountBounds,
                    categories: filterCategories,
                    currencyCode: currencyCode
                )
                .presentationDetents([.medium, .large])
            }
            .overlay(undoSnackbar, alignment: .bottom)
        }
    }
}

// MARK: - Sections

extension ExpensesListView {
    private var transactionHeader: some View {
        VStack(spacing: 0) {
            if searchQuery.isEmpty {
                monthYearPicker
            } else {
                Text("All months")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !filteredExpenses.isEmpty {
                TransactionSummaryCard(
                    income: totalIncome,
                    spent: totalSpent,
                    net: netCashflow,
                    itemCount: filteredExpenses.count,
                    budget: analyticsViewModel.currentBudget,
                    currencyCode: currencyCode
                )
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
        }
        .padding(.top, 8)
    }

    private var transactionList: some View {
        List {
            if dynamicTypeSize.isAccessibilitySize {
                transactionHeader
                    .listRowInsets(.init())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

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
                            onDelete: viewModel.isTransferFee(expense) ? nil : {
                                deleteExpenseByID(expense)
                            }
                        )
                    }
                } header: {
                    HStack {
                        Image(systemName: category.iconName)
                            .foregroundStyle(category.color.badgeForeground)
                            .font(.caption)
                            .frame(width: 28, height: 28)
                            .background(category.color)
                            .clipShape(Circle())
                            .accessibilityHidden(true)

                        Text(category.displayName)
                            .font(.headline)

                        Spacer()

                        let categoryTotal = (groupedExpenses[categoryID] ?? []).reduce(0) { total, transaction in
                            total + transaction.signedAmount
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
        .opacity(reduceMotion || isListLoaded ? 1 : 0)
        .animation(reduceMotion ? nil : .easeIn(duration: 0.3), value: isListLoaded)
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
                Label("Sort Transactions", systemImage: "arrow.up.arrow.down")
            }
            .accessibilityLabel("Sort Transactions")

            Menu {
                Picker("Type", selection: $selectedTransactionFilter) {
                    ForEach(TransactionFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
            } label: {
                Label("Transaction Type", systemImage: "line.3.horizontal.decrease")
            }
            .accessibilityLabel("Transaction Type")

            Button {
                showingFilterSheet = true
            } label: {
                Label(
                    "Filter Transactions",
                    systemImage: amountBounds.isActive || selectedCategoryIDs.count < filterCategoryIDs.count
                        ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
                )
            }
        }
        .labelStyle(.iconOnly)
    }

    private var monthYearPicker: some View {
        MonthYearPicker(
            selectedMonth: $selectedMonth,
            selectedYear: $selectedYear,
            monthsToShow: monthHistoryLength
        )
        .padding(.horizontal)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.gray.opacity(0.6))
                .padding()

            Text("No Transactions Found")
                .font(.title2)
                .fontWeight(.bold)

            if !searchQuery.isEmpty {
                Text("Try adjusting your search or filters")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else if amountBounds.isActive || selectedCategoryIDs.count < filterCategoryIDs.count
                        || selectedTransactionFilter != .all {
                Text("Try adjusting your filters")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button {
                    selectedCategoryIDs = Set(filterCategoryIDs)
                    selectedTransactionFilter = .all
                    amountBounds = TransactionAmountBounds()
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
                    Label("Add Transaction", systemImage: "plus")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
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
                        .accessibilityHidden(true)

                    Text("Transaction deleted")

                    Spacer()

                    Button("Undo") {
                        undoDelete()
                    }
                    .foregroundStyle(Color.accentColor)
                    .fontWeight(.bold)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .shadow(color: Color(.label).opacity(0.15), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(reduceMotion ? .identity : .move(edge: .bottom).combined(with: .opacity))
                .animation(reduceMotion ? nil : .spring(), value: showUndoSnackbar)
            }
        }
    }

    private func refreshExpenses() {
        viewModel.loadExpenses()
    }

    private func deleteExpenseByID(_ expense: Expense) {
        if let deletedExpense = viewModel.removeExpense(id: expense.id) {
            recentlyDeletedExpenses = [deletedExpense]

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
        viewModel.restoreExpenses(recentlyDeletedExpenses)
        recentlyDeletedExpenses.removeAll()
        showUndoSnackbar = false
    }
}

#Preview {
    ExpensesListView(viewModel: ExpenseViewModel())
        .environmentObject(SettingsViewModel())
        .environmentObject(CategoryStore())
        .environmentObject(WalletsViewModel())
}
