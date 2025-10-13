import SwiftUI

/// Available analytics tabs
enum AnalyticsTab {
    case overview
    case trends
    case insights
    case budget
}

/// Reusable tab selector for analytics view
struct AnalyticsTabSelector: View {
    @Binding var selectedTab: AnalyticsTab
    
    var body: some View {
        HStack(spacing: 2) {
            tabButton(title: "Overview", tab: .overview)
            tabButton(title: "Trends", tab: .trends)
            tabButton(title: "Insights", tab: .insights)
            tabButton(title: "Budget", tab: .budget)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private func tabButton(title: String, tab: AnalyticsTab) -> some View {
        Button(action: {
            withAnimation {
                selectedTab = tab
            }
        }) {
            Text(title)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fontWeight(selectedTab == tab ? .semibold : .regular)
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                )
                .foregroundColor(selectedTab == tab ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack {
        AnalyticsTabSelector(selectedTab: .constant(.overview))
        AnalyticsTabSelector(selectedTab: .constant(.trends))
        AnalyticsTabSelector(selectedTab: .constant(.insights))
        AnalyticsTabSelector(selectedTab: .constant(.budget))
    }
    .padding()
} 
