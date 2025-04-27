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

    var body: some View {
        NavigationView {
            VStack {
                monthYearPicker
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
                    Chart {
                        ForEach(analyticsViewModel.spendingByCategory.sorted(by: { $0.value > $1.value }), id: \.key) { category, amount in
                            SectorMark(
                                angle: .value("Amount", amount),
                                innerRadius: .ratio(0.5),
                                angularInset: 1.5
                            )
                            .foregroundStyle(by: .value("Category", category.displayName))
                        }
                    }
                    .chartLegend(.visible)
                    .frame(height: 300)
                    .padding()
                }
            }
            .navigationTitle("Analytics")

        }
    }
    
    private var monthYearPicker: some View {
        HStack {
            Picker("Month", selection: $analyticsViewModel.selectedMonth) {
                ForEach(1...12, id: \.self) { month in
                    Text(Calendar.current.monthSymbols[month - 1]).tag(month)
                }
            }
            .pickerStyle(MenuPickerStyle())

            Picker("Year", selection: $analyticsViewModel.selectedYear) {
                let currentYear = Calendar.current.component(.year, from: Date())
                ForEach((currentYear-5)...currentYear, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(MenuPickerStyle())

            .pickerStyle(MenuPickerStyle())
        }
        .padding()
        .onChange(of: analyticsViewModel.selectedMonth) { _ in
            analyticsViewModel.calculateAnalytics()
        }
        .onChange(of: analyticsViewModel.selectedYear) { _ in
            analyticsViewModel.calculateAnalytics()
        }
    }
    
    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Monthly Budget:")
                    .font(.headline)

                Spacer()

                TextField("Amount", value: $analyticsViewModel.currentBudget, format: .currency(code: "USD"))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
                    .textFieldStyle(.roundedBorder)
            }

            Button("Save Budget") {
                saveBudget()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
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
                
                Text("Spent \(analyticsViewModel.totalSpent, format: .currency(code: "USD")) out of \(analyticsViewModel.currentBudget, format: .currency(code: "USD"))")
                    .font(.subheadline)
                    .foregroundColor(progress >= 1.0 ? .red : .primary)
            }
        }
        .padding(.horizontal)
    }


    private func saveBudget() {
        let key = analyticsViewModel.budgetKey(forMonth: analyticsViewModel.selectedMonth, year: analyticsViewModel.selectedYear)
        analyticsViewModel.monthlyBudgets[key] = analyticsViewModel.currentBudget
    }


}



#Preview {
    AnalyticsView(analyticsViewModel: AnalyticsViewModel(expenses: []))
}
