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
            // Save to standard UserDefaults
            UserDefaults.standard.set(selectedCurrency, forKey: "selectedCurrency")
            
            // Also save to shared app group UserDefaults for widget access
            let sharedDefaults = UserDefaults(suiteName: StorageService.appGroupID)
            sharedDefaults?.set(selectedCurrency, forKey: "selectedCurrency")
            sharedDefaults?.synchronize() // Force immediate write
            
            print("Currency updated to: \(selectedCurrency), saved to shared defaults: \(StorageService.appGroupID)")
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
        // Get the shared UserDefaults for settings
        let sharedDefaults = UserDefaults(suiteName: StorageService.appGroupID)
        
        // Load currency setting - try shared first, then standard 
        if let savedCurrency = sharedDefaults?.string(forKey: "selectedCurrency") {
            self.selectedCurrency = savedCurrency
            print("SettingsViewModel loaded currency from shared defaults: \(savedCurrency)")
        } else if let savedCurrency = UserDefaults.standard.string(forKey: "selectedCurrency") {
            self.selectedCurrency = savedCurrency
            print("SettingsViewModel loaded currency from standard defaults: \(savedCurrency)")
            
            // Sync this value to shared defaults
            sharedDefaults?.set(savedCurrency, forKey: "selectedCurrency")
            sharedDefaults?.synchronize()
        } else {
            self.selectedCurrency = "USD"
            print("SettingsViewModel using default currency: USD")
            
            // Set default in both places
            UserDefaults.standard.set("USD", forKey: "selectedCurrency")
            sharedDefaults?.set("USD", forKey: "selectedCurrency")
            sharedDefaults?.synchronize()
        }
        
        // Load other settings from standard UserDefaults
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
        // First try to get from shared defaults
        let sharedDefaults = UserDefaults(suiteName: StorageService.appGroupID)
        
        if let sharedDefaults = sharedDefaults {
            // Force sync to make sure we have latest data
            sharedDefaults.synchronize()
            
            if let currency = sharedDefaults.string(forKey: "selectedCurrency") {
                return currency
            }
        }
        
        // Fall back to standard defaults
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