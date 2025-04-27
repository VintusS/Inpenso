//
//  Category.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Foundation
import AppIntents

enum Category: String, CaseIterable, Codable, AppEnum {
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

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"

    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .food: "Food",
        .rent: "Rent",
        .shopping: "Shopping",
        .entertainment: "Entertainment",
        .transportation: "Transportation",
        .utilities: "Utilities",
        .subscriptions: "Subscriptions",
        .healthcare: "Healthcare",
        .education: "Education",
        .others: "Others"
    ]
}
