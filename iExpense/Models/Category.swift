//
//  Category.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Foundation
import AppIntents
import SwiftUI

enum Category: String, CaseIterable, Codable, AppEnum {
    case food
    case eatingOut
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
        case .eatingOut: return "Eating Out"
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
        .eatingOut: "Eating Out",
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

extension Category {
    var color: Color {
        switch self {
        case .food:
            return .green
        case .eatingOut:
            return .mint
        case .rent:
            return .purple
        case .shopping:
            return .orange
        case .entertainment:
            return .pink
        case .transportation:
            return .blue
        case .utilities:
            return .yellow
        case .subscriptions:
            return .teal
        case .healthcare:
            return .red
        case .education:
            return .indigo
        case .others:
            return .gray
        }
    }
}

