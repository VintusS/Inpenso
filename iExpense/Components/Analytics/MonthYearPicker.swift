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
    var monthYearList: [MonthYear]
    var onMonthYearChanged: (() -> Void)? = nil
    
    @State private var selectedIndex: Int = 0
    
    init(
        selectedMonth: Binding<Int>,
        selectedYear: Binding<Int>,
        monthsToShow: Int = 36,
        onMonthYearChanged: (() -> Void)? = nil
    ) {
        self._selectedMonth = selectedMonth
        self._selectedYear = selectedYear
        self.onMonthYearChanged = onMonthYearChanged
        
        // Generate the month-year list
        var list: [MonthYear] = []
        let calendar = Calendar.current
        if let today = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: Date()) {
            for i in 0..<monthsToShow {
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
        TabView(selection: $selectedIndex) {
            ForEach(Array(monthYearList.enumerated()), id: \.element.id) { index, monthYear in
                Text(monthYear.displayName)
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
        .frame(height: 60)
        .onChange(of: selectedIndex) { newIndex in
            let monthYear = monthYearList[newIndex]
            
            // Prevent selecting future months
            if monthYear.isFuture() {
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
        .onAppear {
            // Synchronize the picker with the current selection
            if let index = monthYearList.firstIndex(where: { $0.month == selectedMonth && $0.year == selectedYear }) {
                selectedIndex = index
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        MonthYearPicker(
            selectedMonth: .constant(Calendar.current.component(.month, from: Date())),
            selectedYear: .constant(Calendar.current.component(.year, from: Date()))
        )
        
        Text("Select a month by swiping")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
    .previewLayout(.sizeThatFits)
} 