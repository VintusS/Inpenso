//
//  Expense.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Foundation

struct Expense: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var price: Double
    var date: Date
    var category: Category
}
