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
