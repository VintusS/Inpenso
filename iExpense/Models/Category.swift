//
//  Category.swift
//  iExpense
//
//  Created by Dragomir Mindrescu on 27.04.2025.
//

import Foundation
import AppIntents
import SwiftUI

enum TransactionType: String, CaseIterable, Codable, Identifiable {
    case expense
    case income

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .expense:
            return "Expense"
        case .income:
            return "Income"
        }
    }

    var amountColor: Color {
        switch self {
        case .expense:
            return .primary
        case .income:
            return .green
        }
    }
}

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
    var categoryID: String {
        "builtin-\(rawValue)"
    }

    static func category(from id: String) -> Category? {
        guard id.hasPrefix("builtin-") else { return nil }
        return Category(rawValue: String(id.dropFirst("builtin-".count)))
    }

    var defaultIconName: String {
        switch self {
        case .food:
            return "cart.fill"
        case .eatingOut:
            return "fork.knife"
        case .rent:
            return "house.fill"
        case .shopping:
            return "bag.fill"
        case .entertainment:
            return "tv.fill"
        case .transportation:
            return "car.fill"
        case .utilities:
            return "bolt.fill"
        case .subscriptions:
            return "repeat"
        case .healthcare:
            return "heart.fill"
        case .education:
            return "book.fill"
        case .others:
            return "ellipsis"
        }
    }

    var defaultColorHex: String {
        switch self {
        case .food:
            return "#34C759"
        case .eatingOut:
            return "#00C7BE"
        case .rent:
            return "#AF52DE"
        case .shopping:
            return "#FF9500"
        case .entertainment:
            return "#FF2D55"
        case .transportation:
            return "#007AFF"
        case .utilities:
            return "#FFCC00"
        case .subscriptions:
            return "#30B0C7"
        case .healthcare:
            return "#FF3B30"
        case .education:
            return "#5856D6"
        case .others:
            return "#8E8E93"
        }
    }

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

struct FinanceCategory: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var iconName: String
    var colorHex: String
    var isCustom: Bool

    var displayName: String { name }

    var color: Color {
        Color(hex: colorHex) ?? .gray
    }

    static let builtInCategories: [FinanceCategory] = Category.allCases.map { category in
        FinanceCategory(
            id: category.categoryID,
            name: category.displayName,
            iconName: category.defaultIconName,
            colorHex: category.defaultColorHex,
            isCustom: false
        )
    }

    static func builtIn(for category: Category) -> FinanceCategory {
        FinanceCategory(
            id: category.categoryID,
            name: category.displayName,
            iconName: category.defaultIconName,
            colorHex: category.defaultColorHex,
            isCustom: false
        )
    }

    static var fallback: FinanceCategory {
        builtIn(for: .others)
    }
}

struct CategoryCatalogState: Codable, Equatable {
    var orderedCategoryIDs: [String]
    var customCategories: [FinanceCategory]
    var builtInOverrides: [String: FinanceCategory]
    var hiddenCategoryIDs: Set<String>

    init(
        orderedCategoryIDs: [String] = [],
        customCategories: [FinanceCategory] = [],
        builtInOverrides: [String: FinanceCategory] = [:],
        hiddenCategoryIDs: Set<String> = []
    ) {
        self.orderedCategoryIDs = orderedCategoryIDs
        self.customCategories = customCategories
        self.builtInOverrides = builtInOverrides
        self.hiddenCategoryIDs = hiddenCategoryIDs
    }

    enum CodingKeys: String, CodingKey {
        case orderedCategoryIDs
        case customCategories
        case builtInOverrides
        case hiddenCategoryIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderedCategoryIDs = try container.decodeIfPresent([String].self, forKey: .orderedCategoryIDs) ?? []
        customCategories = try container.decodeIfPresent([FinanceCategory].self, forKey: .customCategories) ?? []
        builtInOverrides = try container.decodeIfPresent([String: FinanceCategory].self, forKey: .builtInOverrides) ?? [:]
        hiddenCategoryIDs = try container.decodeIfPresent(Set<String>.self, forKey: .hiddenCategoryIDs) ?? []
    }
}

extension Color {
    init?(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")

        guard sanitized.count == 6,
              let value = Int(sanitized, radix: 16) else {
            return nil
        }

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
