//
//  Category.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Foundation

enum Category: String, CaseIterable, Codable {
    case food
    case rent
    case shopping
    case entertainment
    case transportation
    case utilities
    case subscriptions
    case healthcare
    case education
    case others

    var displayName: String {
        switch self {
        case .food: return "Food"
        case .rent: return "Rent"
        case .shopping: return "Shopping"
        case .entertainment: return "Entertainment"
        case .transportation: return "Transportation"
        case .utilities: return "Utilities"
        case .subscriptions: return "Subscriptions"
        case .healthcare: return "Healthcare"
        case .education: return "Education"
        case .others: return "Others"
        }
    }
}

