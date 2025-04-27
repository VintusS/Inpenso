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
                            VStack(alignment: .leading) {
                                Text(expense.title)
                                    .font(.headline)
                                Text("\(expense.amount, format: .currency(code: "USD"))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(expense.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete { offsets in
                            deleteExpense(at: offsets, in: category)
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
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 80)
            .onChange(of: selectedDateIndex) { newIndex in
                let monthYearList = generateMonthYearList()

                // Protect against scrolling into the future
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
        guard var expensesInCategory = groupedExpenses[category] else { return }
        expensesInCategory.remove(atOffsets: offsets)

        viewModel.expenses = groupedExpenses
            .flatMap { key, value -> [Expense] in
                if key == category {
                    return expensesInCategory
                } else {
                    return value
                }
            }
        viewModel.saveExpenses()
    }
}

#Preview {
    ExpensesListView(viewModel: ExpenseViewModel())
}
