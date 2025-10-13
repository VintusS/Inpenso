import SwiftUI

/// Formats for summary card values
enum SummaryValueFormat {
    case currency
    case percent
    case days
    case count
    case noBudget
    case custom(formatter: (Double) -> String)
}

/// A card that displays a summary value with a title and icon
struct SummaryCard: View {
    let title: String
    let value: Double
    let valueFormat: SummaryValueFormat
    let icon: String
    var color: Color = .blue
    var currencyCode: String
    
    init(
        title: String, 
        value: Double, 
        valueFormat: SummaryValueFormat, 
        icon: String, 
        color: Color = .blue,
        currencyCode: String? = nil
    ) {
        self.title = title
        self.value = value
        self.valueFormat = valueFormat
        self.icon = icon
        self.color = color
        self.currencyCode = currencyCode ?? SettingsViewModel.getAppCurrency()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title with icon
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)

                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            Spacer()

            // Value display based on format
            formattedValue
                .font(.title3)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding()
        .frame(height: 110)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var formattedValue: some View {
        Group {
            switch valueFormat {
            case .currency:
                Text(value, format: .currency(code: currencyCode))
            case .percent:
                Text("\(Int(value))%")
                    .foregroundColor(value >= 90 ? .red : (value >= 75 ? .orange : .primary))
            case .days:
                Text("\(Int(value)) days")
            case .count:
                Text("\(Int(value))")
            case .noBudget:
                Text("Not Set")
                    .foregroundColor(.gray)
            case .custom(let formatter):
                Text(formatter(value))
            }
        }
    }
}

/// A grid of summary cards
struct SummaryCardGrid: View {
    var summaryCards: [SummaryCard]
    var columns: Int = 2
    
    var body: some View {
        let gridItems = Array(repeating: GridItem(.flexible(), spacing: 12), count: columns)
        
        LazyVGrid(columns: gridItems, spacing: 12) {
            ForEach(0..<summaryCards.count, id: \.self) { index in
                summaryCards[index]
            }
        }
        .padding(.vertical)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 20) {
        SummaryCard(
            title: "Total Spent",
            value: 1234.56,
            valueFormat: .currency,
            icon: "dollarsign.circle.fill",
            color: .blue
        )
        
        SummaryCardGrid(summaryCards: [
            SummaryCard(
                title: "Total Spent",
                value: 1234.56,
                valueFormat: .currency,
                icon: "dollarsign.circle.fill",
                color: .blue
            ),
            SummaryCard(
                title: "Budget Used",
                value: 75,
                valueFormat: .percent,
                icon: "chart.pie.fill",
                color: .orange
            ),
            SummaryCard(
                title: "Days Left",
                value: 14,
                valueFormat: .days,
                icon: "calendar",
                color: .purple
            ),
            SummaryCard(
                title: "Budget",
                value: 0,
                valueFormat: .noBudget,
                icon: "chart.pie.fill",
                color: .gray
            )
        ])
    }
    .padding()
} 
