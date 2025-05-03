import SwiftUI
import Charts

/// A chart that displays daily spending data
struct DailySpendingChartView: View {
    struct DailySpending: Identifiable {
        var id: Int { dayOfMonth }
        let date: Date
        let dayOfMonth: Int
        let amount: Double
    }
    
    let dailySpending: [DailySpending]
    let averageDailySpend: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Spending")
                .font(.headline)
            
            if dailySpending.isEmpty {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Chart {
                    ForEach(dailySpending) { daily in
                        BarMark(
                            x: .value("Day", daily.dayOfMonth),
                            y: .value("Amount", daily.amount)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        .cornerRadius(4)
                    }
                    
                    if averageDailySpend > 0 {
                        RuleMark(
                            y: .value("Average", averageDailySpend)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .foregroundStyle(Color.green)
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Avg")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(4)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(4)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: 5)) { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
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

#Preview {
    let sampleData = (1...28).map { day in
        DailySpendingChartView.DailySpending(
            date: Calendar.current.date(from: DateComponents(year: 2025, month: 5, day: day)) ?? Date(),
            dayOfMonth: day,
            amount: Double.random(in: 0...100)
        )
    }
    
    DailySpendingChartView(
        dailySpending: sampleData,
        averageDailySpend: sampleData.reduce(0) { $0 + $1.amount } / Double(sampleData.count)
    )
    .frame(height: 220)
    .padding()
} 