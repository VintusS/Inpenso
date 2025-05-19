//
//  ExpensesListView.swift
//  iExpense
//

import SwiftUI

struct ExpensesListView: View {
    @ObservedObject var viewModel: ExpenseViewModel
    @StateObject private var analyticsViewModel = AnalyticsViewModel(expenses: [])

    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedDateIndex: Int = 0
    @State private var recentlyDeletedExpenses: [Expense] = []
    @State private var showUndoSnackbar: Bool = false
    @State private var undoTimer: Timer? = nil
    @State private var selectedExpenseToEdit: Expense? = nil
    @State private var showingFilterSheet: Bool = false
    @State private var selectedSortOption: SortOption = .dateDescending
    @State private var searchText: String = ""
    @State private var showEmptyState: Bool = false
    @State private var selectedCategories: Set<Category> = Set(Category.allCases)
    @State private var isSearchActive = false
    
    // Animation states
    @State private var isListLoaded = false

    private let monthsPerYear = 12
    private let yearRange = 5

    enum SortOption: String, CaseIterable, Identifiable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case amountDescending = "Highest Amount"
        case amountAscending = "Lowest Amount"
        case titleAscending = "Title A-Z"
        
        var id: String { self.rawValue }
    }
    
    private var totalAmount: Double {
        filteredExpenses.reduce(0) { $0 + $1.price }
    }
    
    private var filteredExpenses: [Expense] {
        var result = viewModel.expenses.filter { expense in
            let month = Calendar.current.component(.month, from: expense.date)
            let year = Calendar.current.component(.year, from: expense.date)
            let matchesDate = month == selectedMonth && year == selectedYear
            let matchesSearch = searchText.isEmpty || 
                expense.title.localizedCaseInsensitiveContains(searchText) ||
                expense.category.displayName.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategories.contains(expense.category)
            
            return matchesDate && matchesSearch && matchesCategory
        }
        
        // Apply sorting
        switch selectedSortOption {
        case .dateDescending:
            result.sort(by: { $0.date > $1.date })
        case .dateAscending:
            result.sort(by: { $0.date < $1.date })
        case .amountDescending:
            result.sort(by: { $0.price > $1.price })
        case .amountAscending:
            result.sort(by: { $0.price < $1.price })
        case .titleAscending:
            result.sort(by: { $0.title < $1.title })
        }
        
        return result
    }
    
    private var groupedExpenses: [Category: [Expense]] {
        Dictionary(grouping: filteredExpenses) { $0.category }
    }
    
    private var visibleCategories: [Category] {
        let categories = Array(groupedExpenses.keys).sorted(by: { $0.displayName < $1.displayName })
        return categories
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Month Year Picker
                    monthYearPicker
                        .padding(.top, 8)
                    
                    // Summary Card
                    if !filteredExpenses.isEmpty {
                        summaryCard
                            .padding(.horizontal)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                    }
                    
                    // Main content
                    if filteredExpenses.isEmpty {
                        emptyStateView
                            .transition(.opacity)
                            .animation(.easeInOut, value: filteredExpenses.isEmpty)
                    } else {
                        List {
                            ForEach(visibleCategories, id: \.self) { category in
                                Section {
                                    ForEach(groupedExpenses[category] ?? []) { expense in
                                        ExpenseRowContent(expense: expense, onEdit: { 
                                            selectedExpenseToEdit = expense
                                        }, onDelete: {
                                            deleteExpenseByID(expense)
                                        })
                                    }
                                } header: {
                                    HStack {
                                        // Fixed-width icon container
                                        ZStack {
                                            Circle()
                                                .fill(category.color)
                                                .frame(width: 28, height: 28)
                                            
                                            Image(systemName: categoryIcon(for: category))
                                                .foregroundColor(.white)
                                                .font(.caption)
                                        }
                                        
                                        Text(category.displayName)
                                            .font(.headline)
                                        
                                        Spacer()
                                        
                                        // Total for this category
                                        let categoryTotal = (groupedExpenses[category] ?? []).reduce(0) { $0 + $1.price }
                                        Text(categoryTotal, format: .currency(code: SettingsViewModel.getAppCurrency()))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                        .opacity(isListLoaded ? 1 : 0)
                        .animation(.easeIn(duration: 0.3), value: isListLoaded)
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search expenses")
            .onChange(of: searchText) { _ in
                withAnimation {
                    isSearchActive = !searchText.isEmpty
                }
            }
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        // Sort button
                        Menu {
                            Picker("Sort by", selection: $selectedSortOption) {
                                ForEach(SortOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                        
                        // Filter button
                        Button(action: {
                            showingFilterSheet = true
                        }) {
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        let newExpense = Expense(title: "", price: 0, date: Date(), category: .food)
                        selectedExpenseToEdit = newExpense
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                refreshExpenses()
            }
            .onAppear {
                syncSelectedDateIndex()
                analyticsViewModel.updateExpenses(viewModel.expenses)
                
                // Animate list appearance
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        isListLoaded = true
                    }
                }
            }
            .onChange(of: viewModel.expenses) { _ in
                analyticsViewModel.updateExpenses(viewModel.expenses)
            }
            .sheet(item: $selectedExpenseToEdit) { expenseToEdit in
                if expenseToEdit.title.isEmpty {
                    // This is a new expense
                    AddExpenseView(viewModel: viewModel)
                } else {
                    // Use ID parameter to force view refresh
                    EditExpenseView(viewModel: viewModel, expense: expenseToEdit)
                        .id(expenseToEdit.id) // Force view to refresh completely on each presentation
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterCategoriesView(selectedCategories: $selectedCategories)
                    .presentationDetents([.medium])
            }
            .overlay(
                VStack {
                    Spacer()
                    if showUndoSnackbar {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            
                            Text("Expense deleted")
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button("Undo") {
                                undoDelete()
                            }
                            .foregroundColor(.yellow)
                            .fontWeight(.bold)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.85))
                                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(), value: showUndoSnackbar)
                    }
                }
            )
        }
    }
    
    // MARK: - Month-Year Picker
    
    private var monthYearPicker: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Left Arrow Button
                Button(action: {
                    if selectedDateIndex > 0 {
                        selectedDateIndex -= 1
                        updateSelection()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(selectedDateIndex > 0 ? .primary : .gray)
                        .padding(.leading, 16) // Added padding
                }
                .disabled(selectedDateIndex == 0)
                
                // TabView for Month-Year Swiping
                TabView(selection: $selectedDateIndex) {
                    ForEach(generateMonthYearList().indices, id: \.self) { index in
                        let monthYear = generateMonthYearList()[index]
                        let month = monthYear.month
                        let year = monthYear.year
                        
                        HStack(spacing: 8) {
                            Text(Calendar.current.monthSymbols[month - 1])
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(String(year))
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
                .onChange(of: selectedDateIndex) {
                    updateSelection()
                }
                .padding(.horizontal, 16) // Added padding
                
                // Right Arrow Button
                Button(action: {
                    let monthYearList = generateMonthYearList()
                    if selectedDateIndex < monthYearList.count - 1 {
                        selectedDateIndex += 1
                        updateSelection()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(selectedDateIndex < generateMonthYearList().count - 1 ? .primary : .gray)
                        .padding(.trailing, 16) // Added padding
                }
                .disabled(selectedDateIndex >= generateMonthYearList().count - 1)
            }
            
            // Month Indicator Dots
            HStack(spacing: 4) {
                ForEach(1...12, id: \.self) { month in
                    Circle()
                        .fill(month == selectedMonth ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.bottom, 8)
            .padding(.horizontal, 16) // Added padding
        }
    }

    // Helper function for updating the selected month and year
    private func updateSelection() {
        let monthYearList = generateMonthYearList()
        let today = Date()
        let calendar = Calendar.current
        let todayMonth = calendar.component(.month, from: today)
        let todayYear = calendar.component(.year, from: today)
        
        if let todayIndex = monthYearList.firstIndex(where: { $0.month == todayMonth && $0.year == todayYear }) {
            if selectedDateIndex > todayIndex {
                selectedDateIndex = todayIndex
                triggerErrorHaptic()
            } else {
                let monthYear = monthYearList[selectedDateIndex]
                selectedMonth = monthYear.month
                selectedYear = monthYear.year
                triggerHaptic()
            }
        }
    }


    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        VStack(spacing: 16) {
            // Total amount for selected month
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total for \(Calendar.current.monthSymbols[selectedMonth - 1])")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(totalAmount, format: .currency(code: SettingsViewModel.getAppCurrency()))
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                // Number of expenses
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Expenses")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(filteredExpenses.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
            
            // Budget progress if available
            if analyticsViewModel.currentBudget > 0 {
                VStack(spacing: 6) {
                    HStack {
                        Text("Monthly Budget")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(totalAmount, format: .currency(code: SettingsViewModel.getAppCurrency()))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("of")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(analyticsViewModel.currentBudget, format: .currency(code: SettingsViewModel.getAppCurrency()))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Progress bar
                    let progress = min(1.0, totalAmount / analyticsViewModel.currentBudget)
                    let progressColor: Color = progress < 0.75 ? .blue : (progress < 0.9 ? .orange : .red)
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(height: 6)
                            
                            // Progress
                            RoundedRectangle(cornerRadius: 4)
                                .fill(progressColor)
                                .frame(width: geometry.size.width * CGFloat(progress), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 70))
                .foregroundColor(.gray.opacity(0.6))
                .padding()
            
            Text("No Expenses Found")
                .font(.title2)
                .fontWeight(.bold)
            
            if !searchText.isEmpty {
                Text("Try adjusting your search or filters")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else if selectedCategories.count < Category.allCases.count {
                Text("Try selecting more categories in the filter")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button(action: {
                    selectedCategories = Set(Category.allCases)
                }) {
                    Text("Reset Filters")
                        .foregroundColor(.accentColor)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentColor, lineWidth: 1)
                        )
                }
                .padding(.top, 8)
            } else {
                Text("Add your first expense for \(Calendar.current.monthSymbols[selectedMonth - 1]) \(selectedYear)")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button(action: {
                    let newExpense = Expense(title: "", price: 0, date: Date(), category: .food)
                    selectedExpenseToEdit = newExpense
                }) {
                    Label("Add Expense", systemImage: "plus")
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color.accentColor)
                        .cornerRadius(10)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Functions
    
    private func generateMonthYearList() -> [(month: Int, year: Int)] {
        let currentYear = Calendar.current.component(.year, from: Date())
        var monthsYears: [(Int, Int)] = []

        for year in (currentYear - yearRange)...(currentYear + yearRange) {
            for month in 1...monthsPerYear {
                monthsYears.append((month, year))
            }
        }
        return monthsYears
    }

    private func syncSelectedDateIndex() {
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        selectedDateIndex = (currentYear - (Calendar.current.component(.year, from: Date()) - yearRange)) * monthsPerYear + (currentMonth - 1)
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func triggerErrorHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    private func refreshExpenses() {
        viewModel.loadExpenses()
    }

    private func deleteExpenseByID(_ expense: Expense) {
        if let index = viewModel.expenses.firstIndex(where: { $0.id == expense.id }) {
            recentlyDeletedExpenses = [expense]
            viewModel.expenses.remove(at: index)
            viewModel.saveExpenses()
            
            showUndoSnackbar = true
            
            undoTimer?.invalidate()
            undoTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
                showUndoSnackbar = false
                recentlyDeletedExpenses.removeAll()
            }
        }
    }
    
    private func undoDelete() {
        undoTimer?.invalidate()
        viewModel.expenses.append(contentsOf: recentlyDeletedExpenses)
        viewModel.saveExpenses()
        recentlyDeletedExpenses.removeAll()
        showUndoSnackbar = false
    }
    
    private func categoryIcon(for category: Category) -> String {
        switch category {
        case .food:
            return "cart.fill"
        case .eatingOut:
            return "fork.knife"
        case .rent:
            return "house.fill"
        case .shopping:
            return "bag.fill"
        case .entertainment:
            return "tv.fill"
        case .transportation:
            return "car.fill"
        case .utilities:
            return "bolt.fill"
        case .subscriptions:
            return "repeat"
        case .healthcare:
            return "heart.fill"
        case .education:
            return "book.fill"
        case .others:
            return "ellipsis"
        }
    }
}

// MARK: - Expense Row View

struct ExpenseRowView: View {
    let expense: Expense
    
    var body: some View {
        HStack(spacing: 12) {
            // Date column
            VStack(alignment: .center, spacing: 2) {
                Text(dayNumber)
                    .font(.system(size: 18, weight: .semibold))
                
                Text(monthShort)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            .frame(width: 40)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
            
            // Title and details
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Price
            Text(expense.price, format: .currency(code: SettingsViewModel.getAppCurrency()))
                .font(.system(.headline, design: .rounded))
                .fontWeight(.bold)
        }
        .padding(.vertical, 6)
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: expense.date)
    }
    
    private var monthShort: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: expense.date)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, d MMM yyyy"
        return formatter.string(from: expense.date)
    }
}

// MARK: - Filter Categories View

struct FilterCategoriesView: View {
    @Binding var selectedCategories: Set<Category>
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempSelectedCategories: Set<Category>
    
    init(selectedCategories: Binding<Set<Category>>) {
        self._selectedCategories = selectedCategories
        self._tempSelectedCategories = State(initialValue: selectedCategories.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section {
                        ForEach(Category.allCases, id: \.self) { category in
                            HStack {
                                // Fixed-width icon container
                                ZStack {
                                    Circle()
                                        .fill(category.color)
                                        .frame(width: 28, height: 28)
                                    
                                    Image(systemName: categoryIcon(for: category))
                                        .foregroundColor(.white)
                                        .font(.caption)
                                }
                                
                                Text(category.displayName)
                                    .font(.body)
                                
                                Spacer()
                                
                                if tempSelectedCategories.contains(category) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if tempSelectedCategories.contains(category) {
                                    if tempSelectedCategories.count > 1 {  // Prevent removing all categories
                                        tempSelectedCategories.remove(category)
                                    }
                                } else {
                                    tempSelectedCategories.insert(category)
                                }
                            }
                        }
                    } header: {
                        Text("Categories")
                    } footer: {
                        Text("Select which expense categories to display")
                    }
                }
                
                HStack(spacing: 12) {
                    Button("Select All") {
                        tempSelectedCategories = Set(Category.allCases)
                    }
                    .foregroundColor(.accentColor)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.accentColor, lineWidth: 1)
                    )
                    
                    Button("Apply") {
                        selectedCategories = tempSelectedCategories
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor)
                    )
                }
                .padding()
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func categoryIcon(for category: Category) -> String {
        switch category {
        case .food:
            return "cart.fill"
        case .eatingOut:
            return "fork.knife"
        case .rent:
            return "house.fill"
        case .shopping:
            return "bag.fill"
        case .entertainment:
            return "tv.fill"
        case .transportation:
            return "car.fill"
        case .utilities:
            return "bolt.fill"
        case .subscriptions:
            return "repeat"
        case .healthcare:
            return "heart.fill"
        case .education:
            return "book.fill"
        case .others:
            return "ellipsis"
        }
    }
}

struct ExpenseRowContent: View {
    let expense: Expense
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        ExpenseRowView(expense: expense)
            .contentShape(Rectangle())
            .onTapGesture {
                print("DEBUG: Tap gesture on expense with ID \(expense.id), title \(expense.title)")
                onEdit()
                print("DEBUG: Directly setting selectedExpenseToEdit")
            }
            .contextMenu {
                Button(action: {
                    onEdit()
                }) {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(role: .destructive, action: {
                    onDelete()
                }) {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading) {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .trailing) {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)
            }
    }
}

#Preview {
    ExpensesListView(viewModel: ExpenseViewModel())
}
