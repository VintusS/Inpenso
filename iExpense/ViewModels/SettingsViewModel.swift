//
//  SettingsViewModel.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Foundation
import SwiftUI
import WidgetKit

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
    ("RUB", "₽", "Russian Ruble"),
    ("IDR", "Rp", "Indonesian Rupiah")
]

@MainActor
class SettingsViewModel: ObservableObject {
    @Published private(set) var isCurrencyLocked = true
    @Published private(set) var selectedCurrency: String = "USD" {
        didSet {
            // Save to standard UserDefaults
            UserDefaults.standard.set(selectedCurrency, forKey: "selectedCurrency")
            
            // Also save to shared app group UserDefaults for widget access
            let sharedDefaults = UserDefaults(suiteName: StorageService.appGroupID)
            sharedDefaults?.set(selectedCurrency, forKey: "selectedCurrency")
            sharedDefaults?.synchronize() // Force immediate write
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    @Published var defaultCategory: Category = .food {
        didSet {
            UserDefaults.standard.set(defaultCategory.rawValue, forKey: "defaultCategory")
        }
    }

    @Published var defaultCategoryID: String = Category.food.categoryID {
        didSet {
            UserDefaults.standard.set(defaultCategoryID, forKey: "defaultCategoryID")

            if let builtInCategory = Category.category(from: defaultCategoryID) {
                defaultCategory = builtInCategory
            }
        }
    }
    
    @Published var selectedTheme: AppTheme = .system {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme")
        }
    }
    
    init() {
        let sharedDefaults = UserDefaults(suiteName: StorageService.appGroupID)
        let ledger = StorageService.loadLedger()
        self.selectedCurrency = ledger?.currency
            ?? sharedDefaults?.string(forKey: "selectedCurrency")
            ?? UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD"
        self.isCurrencyLocked = ledger?.hasActivity ?? true

        let savedCategory = UserDefaults.standard.string(forKey: "defaultCategory")
        self.defaultCategory = Category(rawValue: savedCategory ?? "food") ?? .food
        self.defaultCategoryID = UserDefaults.standard.string(forKey: "defaultCategoryID") ?? self.defaultCategory.categoryID
        
        let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme")
        self.selectedTheme = AppTheme(rawValue: savedTheme ?? "system") ?? .system
    }
    
    func exportBackup() throws -> URL {
        try BackupService.writeBackupFile()
    }

    func previewRestore(from url: URL) throws -> RestorePreview {
        let data = try Data(contentsOf: url)
        let (backup, isLegacy) = try BackupService.readBackup(from: data, currentCurrencyCode: selectedCurrency)
        return BackupService.preview(backup, isLegacy: isLegacy, currentCurrencyCode: selectedCurrency)
    }

    func refreshLedgerCurrency() {
        let ledger = StorageService.loadLedger()
        isCurrencyLocked = ledger?.hasActivity ?? true
        if let currency = ledger?.currency, selectedCurrency != currency {
            selectedCurrency = currency
        }
    }

    func changeCurrency(to currency: String) throws {
        defer { refreshLedgerCurrency() }
        guard currency != selectedCurrency else { return }
        try StorageService.updateLedger { ledger in
            guard !ledger.hasActivity else { throw CurrencyChangeError.ledgerHasActivity }
            ledger.currency = currency
        }
    }

    func applyRestore(_ preview: RestorePreview, mode: RestoreMode) throws {
        try BackupService.restore(preview.backup, mode: mode)
        refreshLedgerCurrency()
    }

    func resetAllData() {
        do {
            try StorageService.clearExpenses()
            StorageService.saveBudgets([:])
            refreshLedgerCurrency()
            NotificationCenter.default.post(name: .inpensoDataDidChange, object: nil)
        } catch {
            NSLog("Unable to reset ledger: %@", error.localizedDescription)
        }
    }

    // Static method to get app-wide settings without needing to initialize
    static func getAppCurrency() -> String {
        if let currency = StorageService.loadLedger()?.currency { return currency }
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
    let code = StorageService.loadLedger()?.currency ?? UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD"
    if let currency = availableCurrencies.first(where: { $0.code == code }) {
        return currency.symbol
    }
    return "$" // Default fallback
}

private enum CurrencyChangeError: LocalizedError {
    case ledgerHasActivity

    var errorDescription: String? {
        "Currency is locked while the ledger contains transactions or transfers."
    }
}
