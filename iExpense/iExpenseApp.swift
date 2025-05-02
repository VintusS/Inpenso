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
        
        print("App launch: Using app group ID: \(StorageService.appGroupID)")
        
        // Sync currency setting
        if let currency = UserDefaults.standard.string(forKey: "selectedCurrency") {
            sharedDefaults?.set(currency, forKey: "selectedCurrency")
            sharedDefaults?.synchronize()
            print("App launch: Synced currency \(currency) to shared defaults")
        } else {
            // If no currency in standard defaults, set a default in both places
            let defaultCurrency = "USD"
            UserDefaults.standard.set(defaultCurrency, forKey: "selectedCurrency")
            sharedDefaults?.set(defaultCurrency, forKey: "selectedCurrency")
            sharedDefaults?.synchronize()
            print("App launch: Set default currency \(defaultCurrency) in both defaults")
        }
        
        // Verify that the value was correctly saved by reading it back
        let syncedCurrency = sharedDefaults?.string(forKey: "selectedCurrency")
        print("App launch: Verification - currency in shared defaults: \(syncedCurrency ?? "nil")")
    }
}
