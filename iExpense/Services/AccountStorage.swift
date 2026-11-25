//
//  AccountStorage.swift
//  iExpense
//
//  Persistence for bank accounts / cards. Kept separate from
//  StorageService because that file is also compiled into the widget
//  target, which doesn't include the Account model.
//

import Foundation

struct AccountStorage {
    private static let accountsKey = "accounts"

    private static var userDefaults: UserDefaults? {
        UserDefaults(suiteName: StorageService.appGroupID)
    }

    static func save(_ accounts: [Account]) {
        guard let userDefaults = userDefaults else { return }
        do {
            let data = try JSONEncoder().encode(accounts)
            userDefaults.set(data, forKey: accountsKey)
        } catch {
            // Error handling without print
        }
    }

    static func load() -> [Account] {
        guard let userDefaults = userDefaults,
              let data = userDefaults.data(forKey: accountsKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([Account].self, from: data)
        } catch {
            return []
        }
    }
}
