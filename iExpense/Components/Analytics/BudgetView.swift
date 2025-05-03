import SwiftUI
import Charts

/// A component for inputting and saving a budget
struct BudgetInputView: View {
    @Binding var currentBudget: Double
    let currencyCode: String
    let onSave: () -> Void
    
    init(
        currentBudget: Binding<Double>,
        currencyCode: String? = nil,
        onSave: @escaping () -> Void
    ) {
        self._currentBudget = currentBudget
        self.currencyCode = currencyCode ?? SettingsViewModel.getAppCurrency()
        self.onSave = onSave
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set Monthly Budget")
                .font(.headline)
            
            VStack(spacing: 16) {
                HStack {
                    Text("Budget Amount")
                        .font(.subheadline)

                    Spacer()

                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.tertiarySystemBackground))
                            .frame(width: 150, height: 40)
                        
                        TextField("0", value: $currentBudget, format: .currency(code: currencyCode))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .padding(.horizontal, 10)
                            .frame(width: 150, height: 40)
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                hideKeyboard()
                            }
                        }
                    }
                }

                Button(action: onSave) {
                    Text("Save Budget")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// A component that displays budget status information
struct BudgetStatusView: View {
    let totalSpent: Double
    let currentBudget: Double
    let daysRemainingInMonth: Int
    let budgetRemainingPerDay: Double
    let currencyCode: String
    
    init(
        totalSpent: Double,
        currentBudget: Double,
        daysRemainingInMonth: Int,
        budgetRemainingPerDay: Double,
        currencyCode: String? = nil
    ) {
        self.totalSpent = totalSpent
        self.currentBudget = currentBudget
        self.daysRemainingInMonth = daysRemainingInMonth
        self.budgetRemainingPerDay = budgetRemainingPerDay
        self.currencyCode = currencyCode ?? SettingsViewModel.getAppCurrency()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget Status")
                .font(.headline)
            
            VStack(spacing: 16) {
                // Progress bar
                let progress = min(1.0, totalSpent / currentBudget)
                let progressColor: Color = progress < 0.75 ? .blue : (progress < 0.9 ? .orange : .red)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(Int(progress * 100))% Used")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int((1 - progress) * 100))% Remaining")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray5))
                                .frame(height: 12)
                            
                            // Progress
                            RoundedRectangle(cornerRadius: 6)
                                .fill(progressColor)
                                .frame(width: geometry.size.width * CGFloat(progress), height: 12)
                        }
                    }
                    .frame(height: 12)
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Spent")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(totalSpent, format: .currency(code: currencyCode))
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(max(0, currentBudget - totalSpent), format: .currency(code: currencyCode))
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }
                
                if daysRemainingInMonth > 0 {
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Days Remaining")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(daysRemainingInMonth) days")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Daily Budget Left")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(budgetRemainingPerDay, format: .currency(code: currencyCode))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
}

/// A component that displays budget recommendations
struct BudgetRecommendationsView: View {
    let biggestExpenseCategory: (category: Category, amount: Double)?
    let totalSpent: Double
    let currentBudget: Double
    let daysRemainingInMonth: Int
    let suggestedBudget: Double
    let currencyCode: String
    
    init(
        biggestExpenseCategory: (category: Category, amount: Double)?,
        totalSpent: Double,
        currentBudget: Double,
        daysRemainingInMonth: Int,
        suggestedBudget: Double,
        currencyCode: String? = nil
    ) {
        self.biggestExpenseCategory = biggestExpenseCategory
        self.totalSpent = totalSpent
        self.currentBudget = currentBudget
        self.daysRemainingInMonth = daysRemainingInMonth
        self.suggestedBudget = suggestedBudget
        self.currencyCode = currencyCode ?? SettingsViewModel.getAppCurrency()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations")
                .font(.headline)
            
            VStack(spacing: 16) {
                // Recommend categories to cut
                if let (category, amount) = biggestExpenseCategory, 
                   totalSpent > currentBudget {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Consider Reducing")
                                .font(.subheadline)
                            
                            HStack {
                                Circle()
                                    .fill(category.color)
                                    .frame(width: 8, height: 8)
                                
                                Text(category.displayName)
                                    .font(.system(size: 15, weight: .semibold))
                            }
                        }
                        
                        Spacer()
                        
                        Text(amount, format: .currency(code: currencyCode))
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .padding(.horizontal)
                }
                
                // Daily spending target when over budget
                if totalSpent > currentBudget && daysRemainingInMonth > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("To Get Back on Track")
                            .font(.subheadline)
                        
                        Text("You need to spend \(currentBudget * 0.9 - totalSpent, format: .currency(code: currencyCode)) less than budgeted for the rest of the month.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                // Suggested next month's budget based on trends
                if suggestedBudget > 0 && abs(suggestedBudget - currentBudget) / currentBudget > 0.1 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Suggested Next Month")
                            .font(.subheadline)
                        
                        HStack {
                            Text(suggestedBudget, format: .currency(code: currencyCode))
                                .font(.system(size: 15, weight: .semibold))
                            
                            if suggestedBudget > currentBudget {
                                Text("(+\(Int((suggestedBudget - currentBudget) / currentBudget * 100))%)")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } else {
                                Text("(-\(Int((currentBudget - suggestedBudget) / currentBudget * 100))%)")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
}

/// A component that displays budget compliance history
struct BudgetHistoryView: View {
    struct BudgetComplianceData {
        let month: Int
        let year: Int
        let monthName: String
        let compliancePercent: Double
        let color: Color
    }
    
    let complianceData: [BudgetComplianceData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget History")
                .font(.headline)
            
            // Check if we have enough budget history
            if complianceData.isEmpty {
                Text("Not enough budget history yet")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
            } else {
                VStack {
                    Chart {
                        ForEach(complianceData, id: \.month) { data in
                            BarMark(
                                x: .value("Month", data.monthName),
                                y: .value("Percent", data.compliancePercent)
                            )
                            .foregroundStyle(data.color)
                            .cornerRadius(4)
                        }
                        
                        // Budget line with properly positioned label
                        RuleMark(y: .value("Budget", 100))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .foregroundStyle(Color.gray)
                            .annotation(position: .top, alignment: .trailing, spacing: 0) {
                                Text("Budget")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .padding(4)
                                    .background(Color(.tertiarySystemBackground))
                                    .cornerRadius(4)
                                    .offset(x: -20)
                            }
                    }
                    .frame(height: 200)
                    .padding(.trailing, 30) // Add padding to make room for label
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisValueLabel(format: Decimal.FormatStyle.Percent.percent)
                        }
                    }
                    
                    // Summary text
                    let onBudgetMonths = complianceData.filter { $0.compliancePercent <= 100 }.count
                    let totalMonths = complianceData.count
                    
                    Text("\(onBudgetMonths) of \(totalMonths) months on or under budget")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Budget Input preview
        BudgetInputView(
            currentBudget: .constant(2500.00),
            onSave: {}
        )
        
        // Budget Status preview
        BudgetStatusView(
            totalSpent: 1875.50,
            currentBudget: 2500.00,
            daysRemainingInMonth: 14,
            budgetRemainingPerDay: 44.61
        )
        
        // Budget Recommendations preview
        BudgetRecommendationsView(
            biggestExpenseCategory: (Category.food, 450.50),
            totalSpent: 1875.50,
            currentBudget: 2500.00,
            daysRemainingInMonth: 14,
            suggestedBudget: 2700.00
        )
        
        // Budget History preview
        BudgetHistoryView(complianceData: [
            BudgetHistoryView.BudgetComplianceData(
                month: 1,
                year: 2025,
                monthName: "Jan",
                compliancePercent: 85.0,
                color: .green
            ),
            BudgetHistoryView.BudgetComplianceData(
                month: 2,
                year: 2025,
                monthName: "Feb",
                compliancePercent: 95.0,
                color: .blue
            ),
            BudgetHistoryView.BudgetComplianceData(
                month: 3,
                year: 2025,
                monthName: "Mar",
                compliancePercent: 120.0,
                color: .red
            )
        ])
    }
    .padding()
} 