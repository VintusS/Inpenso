//
//  ExpensesListView.swift
//  iExpense
//

import SwiftUI

struct ExpensesListView: View {
    @ObservedObject var viewModel: ExpenseViewModel

    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedDateIndex: Int = 0
    @State private var recentlyDeletedExpenses: [Expense] = []
    @State private var showUndoSnackbar: Bool = false
    @State private var undoTimer: Timer? = nil
    @State private var selectedExpenseToEdit: Expense? = nil
    @State private var showingEditSheet: Bool = false

    private let monthsPerYear = 12
    private let yearRange = 5

    private var groupedExpenses: [Category: [Expense]] {
        let filtered = viewModel.expenses.filter { expense in
            let month = Calendar.current.component(.month, from: expense.date)
            let year = Calendar.current.component(.year, from: expense.date)
            return month == selectedMonth && year == selectedYear
        }
        return Dictionary(grouping: filtered) { $0.category }
    }

    var body: some View {
        NavigationView {
            List {
                unifiedMonthYearPickerSection

                ForEach(groupedExpenses.keys.sorted(by: { $0.displayName < $1.displayName }), id: \.self) { category in
                    Section(header: Text(category.displayName)) {
                        ForEach(sortedExpenses(for: category)) { expense in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(expense.title)
                                        .font(.headline)

                                    Text(expense.date, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }

                                Spacer()

                                Text(expense.price, format: .currency(code: currentCurrencyCode()))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 4)
                            .swipeActions(edge: .leading) {
                                Button(role: .destructive) {
                                    deleteExpenseByID(expense)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    selectedExpenseToEdit = expense
                                    showingEditSheet = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }

                        }
                        .onDelete { offsets in
                            let expensesToDelete = offsets.map { sortedExpenses(for: category)[$0] }
                            recentlyDeletedExpenses = expensesToDelete
                            viewModel.deleteExpenses(expensesToDelete)

                            showUndoSnackbar = true

                            undoTimer?.invalidate()
                            undoTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
                                showUndoSnackbar = false
                                recentlyDeletedExpenses.removeAll()
                            }
                        }

                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                refreshExpenses()
            }
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .onAppear {
                syncSelectedDateIndex()
            }
            .overlay(
                VStack {
                    Spacer()
                    if showUndoSnackbar {
                        HStack {
                            Text("Expense deleted")
                                .foregroundColor(.white)
                            Spacer()
                            Button("Undo") {
                                undoDelete()
                            }
                            .foregroundColor(.yellow)
                            .fontWeight(.bold)
                        }
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut, value: showUndoSnackbar)
                    }
                }
            )
            .sheet(isPresented: $showingEditSheet) {
                if let expenseToEdit = selectedExpenseToEdit {
                    EditExpenseView(viewModel: viewModel, expense: expenseToEdit)
                }
            }
        }
    }

    // MARK: - Month-Year Picker inside List Section

    private var unifiedMonthYearPickerSection: some View {
        Section {
            TabView(selection: $selectedDateIndex) {
                ForEach(generateMonthYearList().indices, id: \.self) { index in
                    let monthYear = generateMonthYearList()[index]
                    let month = monthYear.month
                    let year = monthYear.year

                    Text("\(Calendar.current.monthSymbols[month - 1]) \(String(year))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 40)
            .onChange(of: selectedDateIndex) { newIndex in
                let monthYearList = generateMonthYearList()
                let today = Date()
                let calendar = Calendar.current
                let todayMonth = calendar.component(.month, from: today)
                let todayYear = calendar.component(.year, from: today)

                if let todayIndex = monthYearList.firstIndex(where: { $0.month == todayMonth && $0.year == todayYear }) {
                    if newIndex > todayIndex {
                        selectedDateIndex = todayIndex
                        triggerErrorHaptic()
                    } else {
                        let monthYear = monthYearList[newIndex]
                        selectedMonth = monthYear.month
                        selectedYear = monthYear.year
                        triggerHaptic()
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func generateMonthYearList() -> [(month: Int, year: Int)] {
        let currentYear = Calendar.current.component(.year, from: Date())
        var monthsYears: [(Int, Int)] = []

        for year in (currentYear - yearRange)...(currentYear + yearRange) {
            for month in 1...monthsPerYear {
                monthsYears.append((month, year))
            }
        }
        return monthsYears
    }

    private func syncSelectedDateIndex() {
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        selectedDateIndex = (currentYear - (Calendar.current.component(.year, from: Date()) - yearRange)) * monthsPerYear + (currentMonth - 1)
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func triggerErrorHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    private func refreshExpenses() {
        viewModel.loadExpenses()
    }

    private func sortedExpenses(for category: Category) -> [Expense] {
        (groupedExpenses[category] ?? []).sorted(by: { $0.date > $1.date })
    }

    private func deleteExpense(at offsets: IndexSet, in category: Category) {
        guard let expensesInCategory = groupedExpenses[category] else { return }
        let expensesToDelete = offsets.map { expensesInCategory[$0] }

        for expense in expensesToDelete {
            if let indexInMainList = viewModel.expenses.firstIndex(where: { $0.id == expense.id }) {
                viewModel.expenses.remove(at: indexInMainList)
            }
        }

        viewModel.saveExpenses()
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

#Preview {
    ExpensesListView(viewModel: ExpenseViewModel())
}
