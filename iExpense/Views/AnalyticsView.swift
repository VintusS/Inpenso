//
//  AnalyticsView.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI
import Charts

struct AnalyticsView: View {
    @ObservedObject var analyticsViewModel: AnalyticsViewModel

    @State private var selectedDateIndex: Int = 0
    private let monthsPerYear = 12
    private let yearRange = 5

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    unifiedMonthYearPicker
                    budgetSection
                    spendingVsBudgetSection

                    Text("Spending by Category")
                        .font(.title2)
                        .bold()
                        .padding(.top)

                    if analyticsViewModel.spendingByCategory.isEmpty {
                        Text("No data available")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        VStack(spacing: 24) {
                            Chart {
                                ForEach(analyticsViewModel.spendingByCategory.sorted(by: { $0.value > $1.value }), id: \.key) { category, price in
                                    SectorMark(
                                        angle: .value("Price", price),
                                        innerRadius: .ratio(0.5),
                                        angularInset: 1.5
                                    )
                                    .foregroundStyle(category.color)
                                }
                            }
                            .frame(height: 300)
                            .padding(.horizontal)
                            .chartLegend(.hidden)

                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(analyticsViewModel.spendingByCategory.sorted(by: { $0.value > $1.value }), id: \.key) { category, price in
                                    HStack {
                                        Circle()
                                            .frame(width: 12, height: 12)
                                            .foregroundStyle(category.color)
                                        Text(category.displayName)
                                            .font(.caption)
                                        Spacer()
                                        Text(price, format: .currency(code: currentCurrencyCode()))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                    }
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .onAppear {
                syncSelectedDateIndex()
            }
        }
        .onAppear {
            syncSelectedDateIndex()
        }

    }

    private var unifiedMonthYearPicker: some View {
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
                    .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .frame(height: 80)
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
                    analyticsViewModel.selectedMonth = monthYear.month
                    analyticsViewModel.selectedYear = monthYear.year
                    analyticsViewModel.calculateAnalytics()
                    triggerHaptic()
                }
            }
        }
    }
    
    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Monthly Budget:")
                    .font(.headline)

                Spacer()

                TextField("Price", value: $analyticsViewModel.currentBudget, format: .currency(code: currentCurrencyCode()))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
                    .textFieldStyle(.roundedBorder)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                hideKeyboard()
                            }
                        }
                    }
            }

            Button("Save Budget") {
                saveBudget()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var spendingVsBudgetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if analyticsViewModel.currentBudget > 0 {
                let progress = min(analyticsViewModel.totalSpent / analyticsViewModel.currentBudget, 1.0)
                
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(progress >= 1.0 ? .red : .blue)
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                    .padding(.vertical)

                Text("Spent \(analyticsViewModel.totalSpent, format: .currency(code: currentCurrencyCode())) out of \(analyticsViewModel.currentBudget, format: .currency(code: currentCurrencyCode()))")
                    .font(.subheadline)
                    .foregroundColor(progress >= 1.0 ? .red : .primary)
            }
        }
    }

    private func saveBudget() {
        let key = analyticsViewModel.budgetKey(forMonth: analyticsViewModel.selectedMonth, year: analyticsViewModel.selectedYear)
        analyticsViewModel.monthlyBudgets[key] = analyticsViewModel.currentBudget
        StorageService.saveBudgets(analyticsViewModel.monthlyBudgets)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func triggerErrorHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func syncSelectedDateIndex() {
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        selectedDateIndex = (currentYear - (Calendar.current.component(.year, from: Date()) - yearRange)) * monthsPerYear + (currentMonth - 1)
    }

    private func generateMonthYearList() -> [(month: Int, year: Int)] {
        let currentYear = Calendar.current.component(.year, from: Date())
        var monthsYears: [(Int, Int)] = []

        for year in (currentYear - yearRange)...(currentYear + yearRange) {
            for month in 1...12 {
                monthsYears.append((month, year))
            }
        }
        return monthsYears
    }

}

#Preview {
    AnalyticsView(analyticsViewModel: AnalyticsViewModel(expenses: []))
}
