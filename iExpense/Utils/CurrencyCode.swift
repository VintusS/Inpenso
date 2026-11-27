//
//  CurrencyCode.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//
//

import Foundation

func currentCurrencyCode() -> String {
    Locale.current.currency?.identifier ?? "USD"
}

/// Number of decimal places a currency uses (e.g. 2 for USD, 0 for JPY and IDR).
func currencyFractionDigits(for currencyCode: String) -> Int {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = currencyCode
    return formatter.maximumFractionDigits
}
