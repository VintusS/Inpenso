//
//  TabSelectionView.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI

/// Available analytics tabs
enum AnalyticsTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case trends = "Trends"
    case insights = "Insights"
    case budget = "Budget"
    
    var id: Self { self }

    var displayName: String {
        switch self {
        case .overview: return String(localized: "Overview")
        case .trends: return String(localized: "Trends")
        case .insights: return String(localized: "Insights")
        case .budget: return String(localized: "Budget")
        }
    }
}

/// Reusable tab selector for analytics view
struct AnalyticsTabSelector: View {
    @Binding var selectedTab: AnalyticsTab
    
    var body: some View {
        Picker("Select a tab", selection: $selectedTab) {
            ForEach(AnalyticsTab.allCases) { tab in
                Text(tab.displayName)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
//        .padding()
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
