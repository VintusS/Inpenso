//
//  iExpenseApp.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI

@main
struct iExpenseApp: App {
    init() {
        // On app launch, ensure settings are synced to the shared UserDefaults
        syncSettingsToSharedDefaults()
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
    
    // This function ensures that all settings needed by widgets are available in shared UserDefaults
    private func syncSettingsToSharedDefaults() {
        let sharedDefaults = UserDefaults(suiteName: StorageService.appGroupID)
        
        // Sync currency setting
        if let currency = UserDefaults.standard.string(forKey: "selectedCurrency") {
            sharedDefaults?.set(currency, forKey: "selectedCurrency")
            sharedDefaults?.synchronize()
        } else {
            // If no currency in standard defaults, set a default in both places
            let defaultCurrency = "USD"
            UserDefaults.standard.set(defaultCurrency, forKey: "selectedCurrency")
            sharedDefaults?.set(defaultCurrency, forKey: "selectedCurrency")
            sharedDefaults?.synchronize()
        }
    }
}
