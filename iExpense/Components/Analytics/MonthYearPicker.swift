//
//  MonthYearPicker.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI

/// A month-year pair for date selection
struct MonthYear: Identifiable, Equatable {
    var id: String { "\(month)-\(year)" }
    let month: Int
    let year: Int
    
    var displayName: String {
        let calendar = Calendar.current
        return "\(calendar.monthSymbols[month - 1]) \(String(year))"
    }
    
    /// Returns true if this month-year is in the future
    func isFuture(relativeTo date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: date)
        let currentYear = calendar.component(.year, from: date)
        
        return (year > currentYear) || (year == currentYear && month > currentMonth)
    }
}

/// A swipeable month-year picker that restricts selection to past months only
struct MonthYearPicker: View {
    @Binding var selectedMonth: Int
    @Binding var selectedYear: Int
    private let monthYearList: [MonthYear]
    private let allowFutureMonths: Bool
    var onMonthYearChanged: (() -> Void)?
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title2) private var accessiblePageHeight = 86
    @State private var selectedIndex: Int = 0
    
    init(
        selectedMonth: Binding<Int>,
        selectedYear: Binding<Int>,
        monthsToShow: Int = 36,
        allowFutureMonths: Bool = false,
        onMonthYearChanged: (() -> Void)? = nil
    ) {
        self._selectedMonth = selectedMonth
        self._selectedYear = selectedYear
        self.onMonthYearChanged = onMonthYearChanged
        self.allowFutureMonths = allowFutureMonths
        
        // Generate the month-year list
        var list: [MonthYear] = []
        let totalMonths = max(monthsToShow, 1)
        let calendar = Calendar.current
        if let today = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: Date()) {
            // Start from the oldest month and go towards the newest
            for i in (0..<totalMonths).reversed() {
                if let date = calendar.date(byAdding: .month, value: -i, to: today) {
                    let month = calendar.component(.month, from: date)
                    let year = calendar.component(.year, from: date)
                    list.append(MonthYear(month: month, year: year))
                }
            }
        }
        self.monthYearList = list
        
        // Find the initial index that matches the selected month and year
        let initialIndex = list.firstIndex(where: { $0.month == selectedMonth.wrappedValue && $0.year == selectedYear.wrappedValue }) ?? 0
        self._selectedIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        HStack {
            Button {
                selectedIndex -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Previous Month")
            .disabled(selectedIndex == 0)

            VStack(spacing: 0) {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(monthYearList.enumerated()), id: \.element.id) { index, monthYear in
                        let layout = dynamicTypeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(spacing: 2))
                            : AnyLayout(HStackLayout(spacing: 8))
                        layout {
                            Text(Calendar.current.monthSymbols[monthYear.month - 1])
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(String(monthYear.year))
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        .multilineTextAlignment(.center)
                        .accessibilityElement(children: .combine)
                        .frame(maxWidth: .infinity)
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: dynamicTypeSize.isAccessibilitySize ? accessiblePageHeight : 50)
                .onChange(of: selectedIndex) {
                    guard monthYearList.indices.contains(selectedIndex) else { return }
                    let monthYear = monthYearList[selectedIndex]
                    
                    // Prevent selecting future months
                    if !allowFutureMonths && monthYear.isFuture() {
                        // Revert to previous selection
                        selectedIndex = monthYearList.firstIndex(where: { $0.month == selectedMonth && $0.year == selectedYear }) ?? 0
                        HapticFeedback.error()
                    } else {
                        // Update selection
                        selectedMonth = monthYear.month
                        selectedYear = monthYear.year
                        HapticFeedback.selection()
                        onMonthYearChanged?()
                    }
                }
                
                // Month indicator dots just like in ExpensesListView
                HStack(spacing: 4) {
                    ForEach(1...12, id: \.self) { month in
                        Circle()
                            .fill(month == selectedMonth ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.bottom, 8)
                .accessibilityHidden(true)
            }
            .onAppear {
                // Synchronize the picker with the current selection
                if let index = monthYearList.firstIndex(where: { $0.month == selectedMonth && $0.year == selectedYear }) {
                    selectedIndex = index
                }
            }
            
            // MARK: - Right Arrow Button
            Button {
                if selectedIndex < monthYearList.count - 1 {
                    selectedIndex += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Next Month")
            .disabled(selectedIndex >= monthYearList.count - 1)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 20) {
        MonthYearPicker(
            selectedMonth: .constant(Calendar.current.component(.month, from: Date())),
            selectedYear: .constant(Calendar.current.component(.year, from: Date()))
        )
    }
    .padding()
}
