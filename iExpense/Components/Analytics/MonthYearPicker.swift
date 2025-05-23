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
            // Start from the oldest month and go towards the newest
            for i in (0..<monthsToShow).reversed() {
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
        VStack(spacing: 0) {
            TabView(selection: $selectedIndex) {
                ForEach(Array(monthYearList.enumerated()), id: \.element.id) { index, monthYear in
                    HStack(spacing: 8) {
                        Text(Calendar.current.monthSymbols[monthYear.month - 1])
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(String(monthYear.year))
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 50)
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
            
            // Month indicator dots just like in ExpensesListView
            HStack(spacing: 4) {
                ForEach(1...12, id: \.self) { month in
                    Circle()
                        .fill(month == selectedMonth ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.bottom, 8)
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