//
//  iExpenseApp.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import SwiftUI
import UserNotifications
import Foundation

@main
struct iExpenseApp: App {
    init() {
        #if DEBUG
        if StorageService.isUnitTestHost { return }
        #endif
        // On app launch, ensure settings are synced to the shared UserDefaults
        syncSettingsToSharedDefaults()
        migrateCategoryKindsOnce()
        #if DEBUG
        importLaunchBackup()
        #endif
    }
    
    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var categoryStore = CategoryStore()
    
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if StorageService.isUnitTestHost {
                Color.clear
            } else {
                appContent
            }
            #else
            appContent
            #endif
        }
    }

    private var appContent: some View {
        MainTabView()
            // Use the optional SwiftData container that won't affect existing code
            .withSwiftData()
            // Perform the migration silently on app startup
            .task {
                await SwiftDataProvider.shared.startMigration()
            }
            .task {
                UNUserNotificationCenter.current().delegate = ForegroundNotificationPresenter.shared
                await ReinstallReminder.schedule()
                #if DEBUG
                await ReinstallReminder.dumpState()
                #endif
            }
            .environmentObject(settingsViewModel)
            .environmentObject(categoryStore)
            .preferredColorScheme(settingsViewModel.selectedTheme.colorScheme)
    }
    
    #if DEBUG
    /// Debug-only data transfer through the app's Documents folder
    /// (`devicectl device copy to/from --domain-type appDataContainer`):
    /// `-exportBackup <file name>` writes the current data there;
    /// `-importBackup <file name> [-importMode replace]` restores a backup (merge by default), then deletes the file.
    private func importLaunchBackup() {
        let arguments = ProcessInfo.processInfo.arguments
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
            return arguments[index + 1]
        }
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        if let name = value(after: "-exportBackup") {
            do {
                try BackupService.encode(BackupService.makeBackup()).write(to: documents.appendingPathComponent(name), options: .atomic)
                NSLog("Exported backup %@", name)
            } catch {
                NSLog("Backup export failed: %@", error.localizedDescription)
            }
        }
        guard let name = value(after: "-importBackup") else { return }
        let url = documents.appendingPathComponent(name)
        let mode: RestoreMode = value(after: "-importMode") == "replace" ? .replace : .merge
        do {
            let currency = StorageService.loadLedger()?.currency ?? "USD"
            let (backup, _) = try BackupService.readBackup(from: Data(contentsOf: url), currentCurrencyCode: currency)
            try BackupService.restore(backup, mode: mode)
            try FileManager.default.removeItem(at: url)
            NSLog("Imported backup %@ (%@)", name, mode == .replace ? "replace" : "merge")
        } catch {
            NSLog("Backup import failed: %@", error.localizedDescription)
        }
    }
    #endif

    /// Income categories arrived after income was saved under expense categories. Re-saving the ledger
    /// lets `prepareForWrite` move those entries; recurring rules are moved when loaded.
    private func migrateCategoryKindsOnce() {
        let key = "categoryKindsMigrated"
        guard !UserDefaults.standard.bool(forKey: key), StorageService.loadLedger() != nil else { return }
        do {
            try StorageService.updateLedger { _ in }
            RecurringService.saveRules(RecurringService.loadRules())
            UserDefaults.standard.set(true, forKey: key)
        } catch {
            NSLog("Category migration failed: %@", error.localizedDescription)
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
