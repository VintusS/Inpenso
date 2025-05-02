//
//  SettingsViewModel.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Foundation
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case light, dark, system
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// Available currencies with symbols - making this global to avoid actor isolation issues
let availableCurrencies: [(code: String, symbol: String, name: String)] = [
    ("USD", "$", "US Dollar"),
    ("EUR", "€", "Euro"),
    ("MDL", "L", "Moldovan Leu"),
    ("GBP", "£", "British Pound"),
    ("JPY", "¥", "Japanese Yen"),
    ("CAD", "$", "Canadian Dollar"),
    ("AUD", "$", "Australian Dollar"),
    ("CHF", "Fr", "Swiss Franc"),
    ("CNY", "¥", "Chinese Yuan"),
    ("INR", "₹", "Indian Rupee"),
    ("RUB", "₽", "Russian Ruble")
]

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var selectedCurrency: String {
        didSet {
            UserDefaults.standard.set(selectedCurrency, forKey: "selectedCurrency")
        }
    }
    
    @Published var defaultCategory: Category {
        didSet {
            UserDefaults.standard.set(defaultCategory.rawValue, forKey: "defaultCategory")
        }
    }
    
    @Published var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme")
        }
    }
    
    @Published var exportFileName: String = "iExpense_export_\(Date().formatted(.dateTime.year().month().day()))"
    
    init() {
        // Load saved settings or use defaults
        if let savedCurrency = UserDefaults.standard.string(forKey: "selectedCurrency") {
            self.selectedCurrency = savedCurrency
        } else {
            self.selectedCurrency = "USD"
        }
        
        if let savedCategoryString = UserDefaults.standard.string(forKey: "defaultCategory"),
           let savedCategory = Category(rawValue: savedCategoryString) {
            self.defaultCategory = savedCategory
        } else {
            self.defaultCategory = .food
        }
        
        if let savedThemeString = UserDefaults.standard.string(forKey: "selectedTheme"),
           let savedTheme = AppTheme(rawValue: savedThemeString) {
            self.selectedTheme = savedTheme
        } else {
            self.selectedTheme = .system
        }
    }
    
    func exportData() -> URL? {
        let expenses = StorageService.loadExpenses()
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(expenses)
            
            let fileManager = FileManager.default
            let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentDirectory.appendingPathComponent("\(exportFileName).json")
            
            try jsonData.write(to: fileURL)
            return fileURL
        } catch {
            print("Error exporting data: \(error)")
            return nil
        }
    }
    
    func importData(from url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let expenses = try decoder.decode([Expense].self, from: data)
            
            StorageService.saveExpenses(expenses)
            return true
        } catch {
            print("Error importing data: \(error)")
            return false
        }
    }
    
    func resetAllData() {
        StorageService.saveExpenses([])
        StorageService.saveBudgets([:])
    }
    
    // Static method to get app-wide settings without needing to initialize
    static func getAppCurrency() -> String {
        return UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD"
    }
}

// Function to get currency symbol - doesn't use main actor
func getSettingsCurrencySymbol() -> String {
    let code = UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD"
    if let currency = availableCurrencies.first(where: { $0.code == code }) {
        return currency.symbol
    }
    return "$" // Default fallback
} 