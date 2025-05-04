//
//  iExpenseApp.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI
import Foundation

@main
struct iExpenseApp: App {
    // Flag to track SwiftData migration status
    @State private var showMigrationMessage = false
    
    init() {
        // On app launch, ensure settings are synced to the shared UserDefaults
        syncSettingsToSharedDefaults()
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                // Use the optional SwiftData container that won't affect existing code
                .withSwiftData()
                // Perform the migration once on app startup
                .task {
                    await SwiftDataProvider.shared.startMigration()
                    showMigrationMessage = SwiftDataProvider.shared.isMigrationCompleted
                }
                // Optionally show a migration success message
                .overlay {
                    if showMigrationMessage {
                        VStack {
                            Spacer()
                            Text("Data migration to SwiftData completed")
                                .font(.caption)
                                .padding(8)
                                .background(.regularMaterial)
                                .cornerRadius(8)
                                .onAppear {
                                    // Automatically hide the message after 3 seconds
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        showMigrationMessage = false
                                    }
                                }
                            Spacer().frame(height: 40)
                        }
                    }
                }
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
