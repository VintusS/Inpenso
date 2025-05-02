//
//  AddExpenseView.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI

struct AddExpenseView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ExpenseViewModel
    @StateObject private var settingsViewModel = SettingsViewModel()
    
    // Form fields
    @State private var title: String = ""
    @State private var price: String = ""
    @State private var selectedCategory: Category
    @State private var selectedDate: Date = Date()
    @State private var notes: String = ""
    
    // UI States
    @State private var showDatePicker = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    @State private var animateSuccess = false
    
    // Current currency symbol
    private var currencySymbol: String {
        let locale = Locale.current
        let currencyCode = SettingsViewModel.getAppCurrency()
        return locale.localizedCurrencySymbol(forCurrencyCode: currencyCode) ?? currencyCode
    }
    
    init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
        // Initialize with the default category from settings
        let defaultCategory = UserDefaults.standard.string(forKey: "defaultCategory") ?? Category.food.rawValue
        _selectedCategory = State(initialValue: Category(rawValue: defaultCategory) ?? .food)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Title and amount card
                        mainDataCard
                        
                        // Category selection
                        categoryCard
                        
                        // Date selection
                        dateCard
                        
                        // Notes
                        notesCard
                        
                        // Save Button
                        saveButton
                            .padding(.vertical, 10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - 40 : 20)
                }
                
                // Success animation overlay
                if animateSuccess {
                    successOverlay
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupKeyboardObservers()
            }
            .onDisappear {
                removeKeyboardObservers()
            }
            .alert(validationMessage, isPresented: $showingValidationAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }
    
    // MARK: - Main Data Card
    
    private var mainDataCard: some View {
        VStack(spacing: 0) {
            // Title field
            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Expense title", text: $title)
                    .font(.headline)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 15)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
                .padding(.horizontal)
            
            // Price field
            VStack(alignment: .leading, spacing: 8) {
                Text("Amount")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .center) {
                    Text(currencySymbol)
                        .foregroundColor(.secondary)
                        .font(.title3)
                        .fontWeight(.medium)
                    
                    TextField("0.00", text: $price)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.leading)
                        .onChange(of: price) { newValue in
                            price = formatPriceInput(newValue)
                        }
                    
                    Spacer()
                    
                    // Clear button
                    if !price.isEmpty {
                        Button(action: {
                            price = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 15)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Category Card
    
    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    // Add leading spacer to prevent items from being cut off
                    Spacer()
                        .frame(width: 5)
                    
                    ForEach(Category.allCases, id: \.self) { category in
                        CategoryButton(
                            category: category,
                            isSelected: selectedCategory == category,
                            action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedCategory = category
                                }
                                triggerHaptic()
                            }
                        )
                    }
                    
                    // Add trailing spacer to prevent items from being cut off
                    Spacer()
                        .frame(width: 5)
                }
                .padding(.horizontal)
                .padding(.vertical, 5)
            }
            .padding(.bottom, 4)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Date Card
    
    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date")
                .font(.headline)
                .padding(.horizontal)
            
            VStack {
                // Date display
                Button(action: {
                    withAnimation {
                        showDatePicker.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.accentColor)
                        
                        Text(formattedDate())
                            .font(.headline)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                            .rotationEffect(Angle(degrees: showDatePicker ? 180 : 0))
                    }
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                // Expandable date picker
                if showDatePicker {
                    DatePicker("", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .labelsHidden()
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onChange(of: selectedDate) { _ in
                            triggerHaptic()
                        }
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Notes Card
    
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes (Optional)")
                .font(.headline)
                .padding(.horizontal)
            
            TextEditor(text: $notes)
                .font(.body)
                .padding(10)
                .frame(minHeight: 100)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 12)
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        Button(action: saveExpense) {
            HStack {
                Spacer()
                Text("Save Expense")
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()
            .background(isFormValid() ? Color.accentColor : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .disabled(!isFormValid())
    }
    
    // MARK: - Success Overlay
    
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("Expense Added!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground).opacity(0.8))
                    .blur(radius: 0.5)
            )
            .scaleEffect(animateSuccess ? 1.0 : 0.5)
            .opacity(animateSuccess ? 1.0 : 0)
            .animation(.spring(), value: animateSuccess)
        }
    }
    
    // MARK: - Helper Methods
    
    private func isFormValid() -> Bool {
        return !title.isEmpty && !price.isEmpty
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: selectedDate)
    }
    
    private func formatPriceInput(_ input: String) -> String {
        // Remove any non-numeric characters except for a single decimal point
        var formattedInput = input.replacingOccurrences(of: ",", with: ".")
        
        // Allow only one decimal point
        let components = formattedInput.components(separatedBy: ".")
        if components.count > 2 {
            formattedInput = components[0] + "." + components[1]
        }
        
        // Limit to two decimal places
        if let decimalIndex = formattedInput.firstIndex(of: ".") {
            let decimalPosition = formattedInput.distance(from: formattedInput.startIndex, to: decimalIndex)
            let maxLength = decimalPosition + 3 // Allow up to 2 decimal places
            
            if formattedInput.count > maxLength {
                let endIndex = formattedInput.index(formattedInput.startIndex, offsetBy: maxLength)
                formattedInput = String(formattedInput[..<endIndex])
            }
        }
        
        return formattedInput
    }
    
    private func saveExpense() {
        // Validate inputs
        if title.isEmpty {
            showValidationAlert("Please enter a title for your expense.")
            return
        }
        
        if price.isEmpty {
            showValidationAlert("Please enter the expense amount.")
            return
        }
        
        price = price.replacingOccurrences(of: ",", with: ".")
        guard let priceValue = Double(price) else {
            showValidationAlert("Please enter a valid amount.")
            return
        }
        
        // Show success animation
        withAnimation {
            animateSuccess = true
        }
        
        // Add the expense with all fields
        viewModel.addExpense(
            title: title,
            price: priceValue,
            category: selectedCategory
        )
        
        // Wait for animation, then dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
    
    private func showValidationAlert(_ message: String) {
        validationMessage = message
        showingValidationAlert = true
    }
    
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                self.keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            self.keyboardHeight = 0
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

// MARK: - Category Button

struct CategoryButton: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    // Base shape
                    Circle()
                        .fill(category.color)
                        .frame(width: 60, height: 60)
                    
                    // Icon
                    Image(systemName: categoryIcon(for: category))
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    
                    // Selection indicator
                    if isSelected {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 60, height: 60)
                    }
                }
                .shadow(color: isSelected ? category.color.opacity(0.6) : Color.clear, radius: isSelected ? 5 : 0)
                
                // Category name
                Text(category.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 75, height: 30)
            }
            .frame(width: 75, height: 105)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
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

// MARK: - Locale Extension

extension Locale {
    func localizedCurrencySymbol(forCurrencyCode currencyCode: String) -> String? {
        let identifier = NSLocale(localeIdentifier: self.identifier).displayName(forKey: .currencySymbol, value: currencyCode)
        return identifier
    }
}

#Preview {
    AddExpenseView(viewModel: ExpenseViewModel())
}
